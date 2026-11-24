--!strict
--[[
	Rôle    : gère l'utilisation des outils (balai, aspirateur) côté serveur.
	          Le client n'envoie que « début » (avec la cible visée) ou « arrêt » ; le serveur
	          valide tout, crée une session, puis revérifie toutes les 0,1 s que l'utilisation
	          reste légitime (outil en main, joueur vivant, cible valide, à portée, visible).
	          Le travail lui-même (progression, bruit, effacement) est fait par une stratégie
	          injectée (voir Utilisations/Nettoyage.luau).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local DefinitionsOutils = require(Partage:WaitForChild("DefinitionsOutils"))
local Remotes = require(Partage:WaitForChild("Remotes"))
local LimiteDebit = require(script.Parent:WaitForChild("LimiteDebit"))

local Reglages = DefinitionsOutils.Reglages

-- Réglages
local PERIODE_VERIFICATION = 0.1 -- secondes entre deux vérifications des sessions
local DT_MAX = 0.5               -- plafond du temps écoulé pris en compte (évite un gros saut après un lag)
local LIMITE_CAPACITE = 6        -- messages client acceptés en rafale
local LIMITE_RECHARGE = 3        -- messages par seconde ensuite

-- Ce que ServiceUtilisation attend de ValidationServeur (interface minimale)
export type Validation = {
	personnageVivant: (joueur: Player) -> (Model?, BasePart?),
	estObjetTagueValide: (objet: unknown, tag: string) -> boolean,
	aPortee: (joueur: Player, objet: Instance, portee: number) -> boolean,
	voit: (joueur: Player, objet: Instance) -> boolean,
	outilEquipe: (joueur: Player) -> (Tool?, Types.DefinitionOutil?),
}

export type Dependances = {
	remotes: Remotes.RemotesOutils,
	validation: Validation,
	strategies: { [string]: Types.StrategieUtilisation },
}

local ServiceUtilisation = {}

function ServiceUtilisation.demarrer(dependances: Dependances)
	local remotes = dependances.remotes
	local validation = dependances.validation
	local strategies = dependances.strategies

	local sessions: { [Player]: Types.SessionUtilisation } = {}
	local limite = LimiteDebit.nouveau(LIMITE_CAPACITE, LIMITE_RECHARGE)

	-- Arrête la session d'un joueur : retire la session, remet l'outil au repos,
	-- laisse la stratégie finir son travail, puis prévient le client.
	local function terminer(joueur: Player, raison: string)
		local session = sessions[joueur]
		if not session then
			return
		end
		sessions[joueur] = nil

		if session.outil.Parent then
			session.outil:SetAttribute(Reglages.ATTRIBUT_EN_UTILISATION, false)
		end

		local definition = session.definition
		local strategie = strategies[definition.utilisation]
		if strategie then
			local ok, erreur = pcall(strategie.finir, session, raison)
			if not ok then
				warn("ServiceUtilisation : erreur dans finir (" .. definition.utilisation .. ") : " .. tostring(erreur))
			end
		end

		if raison ~= "depart" then
			local code = if raison == "fini" then "utilisation_fini" else "utilisation_arretee"
			remotes.RetourOutil:FireClient(joueur, code, definition.id)
		end
	end

	local function repondre(joueur: Player, code: string, idOutil: string?)
		remotes.RetourOutil:FireClient(joueur, code, idOutil)
	end

	-- Traite une demande « debut »
	local function demarrerUtilisation(joueur: Player, cible: unknown)
		local outil, definition = validation.outilEquipe(joueur)
		if not outil or not definition then
			repondre(joueur, "mauvais_outil", nil)
			return
		end

		local strategie = strategies[definition.utilisation]
		if not strategie then
			warn("ServiceUtilisation : pas de stratégie pour « " .. definition.utilisation .. " » (outil " .. definition.id .. ")")
			return
		end

		if not validation.estObjetTagueValide(cible, definition.tagCible) then
			return
		end
		local objet = cible :: Instance

		local outilRequis = objet:GetAttribute(Reglages.ATTRIBUT_OUTIL_REQUIS)
		if type(outilRequis) == "string" and outilRequis ~= definition.id then
			repondre(joueur, "mauvais_outil", definition.id)
			return
		end
		if objet:GetAttribute(Reglages.ATTRIBUT_NETTOYE) == true then
			repondre(joueur, "indisponible", definition.id)
			return
		end
		if not validation.aPortee(joueur, objet, definition.porteeUtilisation) then
			repondre(joueur, "trop_loin", definition.id)
			return
		end
		if not validation.voit(joueur, objet) then
			repondre(joueur, "pas_visible", definition.id)
			return
		end

		-- Déjà une session : même cible = on ignore, sinon on arrête l'ancienne
		local ancienne = sessions[joueur]
		if ancienne then
			if ancienne.cible == objet then
				return
			end
			terminer(joueur, "arret")
		end

		local session: Types.SessionUtilisation = {
			joueur = joueur,
			outil = outil,
			definition = definition,
			cible = objet,
			debut = os.clock(),
			donnees = {},
		}
		local ok, accepte, code = pcall(strategie.commencer, session)
		if not ok then
			warn("ServiceUtilisation : erreur dans commencer (" .. definition.utilisation .. ") : " .. tostring(accepte))
			return
		end
		if not accepte then
			repondre(joueur, code or "indisponible", definition.id)
			return
		end

		sessions[joueur] = session
		outil:SetAttribute(Reglages.ATTRIBUT_EN_UTILISATION, true)
	end

	remotes.DemanderUtilisation.OnServerEvent:Connect(function(joueur: Player, action: unknown, cible: unknown)
		if not limite.consommer(joueur) then
			return
		end
		if action == "arret" then
			if sessions[joueur] then
				terminer(joueur, "arret")
			end
		elseif action == "debut" then
			demarrerUtilisation(joueur, cible)
		end
		-- toute autre action est ignorée
	end)

	-- La session est-elle toujours légitime ?
	local function sessionValide(session: Types.SessionUtilisation): boolean
		local joueur = session.joueur
		local definition = session.definition
		if session.outil.Parent ~= joueur.Character then
			return false
		end
		local personnage = validation.personnageVivant(joueur)
		if not personnage then
			return false
		end
		if not validation.estObjetTagueValide(session.cible, definition.tagCible) then
			return false
		end
		if not validation.aPortee(joueur, session.cible, definition.porteeUtilisation) then
			return false
		end
		return validation.voit(joueur, session.cible)
	end

	-- Boucle de vérification. La durée est mesurée par le serveur (os.clock),
	-- le client ne dit que « début » et « arrêt » : il ne peut pas accélérer le nettoyage.
	task.spawn(function()
		local dernierTemps = os.clock()
		while true do
			task.wait(PERIODE_VERIFICATION)
			local maintenant = os.clock()
			local dt = math.min(maintenant - dernierTemps, DT_MAX)
			dernierTemps = maintenant

			-- copie de la liste : terminer() modifie la table pendant le parcours
			local joueurs = {}
			for joueur in sessions do
				table.insert(joueurs, joueur)
			end

			for _, joueur in joueurs do
				local session = sessions[joueur]
				if not session then
					continue
				end
				if not sessionValide(session) then
					terminer(joueur, "invalide")
					continue
				end
				local strategie = strategies[session.definition.utilisation]
				if not strategie then
					terminer(joueur, "invalide")
					continue
				end
				local ok, resultat = pcall(strategie.avancer, session, dt)
				if not ok then
					warn("ServiceUtilisation : erreur dans avancer : " .. tostring(resultat))
					terminer(joueur, "invalide")
				elseif resultat == "fini" then
					terminer(joueur, "fini")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(joueur: Player)
		terminer(joueur, "depart")
		limite.oublier(joueur)
	end)
end

return ServiceUtilisation
