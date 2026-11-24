--!strict
--[[
	Rôle    : ramassage et achat des outils côté serveur.
	          Reçoit DemanderRamassage(objet), revérifie tout (le client n'est jamais cru),
	          puis donne l'outil (gratuit) ou propose l'achat en Robux (payant).
	          Donne aussi l'outil à l'achat confirmé, et redonne les outils payants
	          déjà possédés quand le joueur se reconnecte.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local DefinitionsOutils = require(Partage:WaitForChild("DefinitionsOutils"))
local RemotesModule = require(Partage:WaitForChild("Remotes"))
local LimiteDebit = require(script.Parent:WaitForChild("LimiteDebit"))

local Reglages = DefinitionsOutils.Reglages

-- Réglages
local CAPACITE_LIMITE = 4          -- demandes de ramassage en rafale
local RECHARGE_LIMITE = 2          -- demandes rendues par seconde
local ATTENTE_BACKPACK = 10        -- secondes max pour attendre le Backpack à la connexion

-- Les dépendances sont injectées (DIP) : ce module ne choisit ni le paiement, ni la fabrique.
type Dependances = {
	remotes: RemotesModule.RemotesOutils,
	paiement: Types.Paiement,
	fabrique: { creer: (definition: Types.DefinitionOutil, objetDecor: Instance?) -> Tool? },
	validation: {
		personnageVivant: (joueur: Player) -> (Model?, BasePart?),
		estObjetTagueValide: (objet: unknown, tag: string) -> boolean,
		aPortee: (joueur: Player, objet: Instance, portee: number) -> boolean,
		voit: (joueur: Player, objet: Instance) -> boolean,
	},
}

local ServiceRamassage = {}

function ServiceRamassage.demarrer(dependances: Dependances)
	local remotes = dependances.remotes
	local paiement = dependances.paiement
	local fabrique = dependances.fabrique
	local validation = dependances.validation

	local limite = LimiteDebit.nouveau(CAPACITE_LIMITE, RECHARGE_LIMITE)
	local reserves: { [Instance]: boolean } = {} -- objets gratuits en cours de ramassage
	local enCours: { [Player]: boolean } = {}    -- joueurs dont un achat est en cours de traitement

	local function repondre(joueur: Player, code: string, id: string?)
		remotes.RetourOutil:FireClient(joueur, code, id)
	end

	-- Le joueur a-t-il déjà cet outil (Backpack, en main, ou StarterGear) ?
	local function possedeDeja(joueur: Player, id: string): boolean
		local conteneurs: { Instance? } = {
			joueur:FindFirstChildOfClass("Backpack"),
			joueur.Character,
			joueur:FindFirstChild("StarterGear"),
		}
		for _, conteneur in conteneurs do
			if conteneur then
				for _, enfant in conteneur:GetChildren() do
					if enfant:IsA("Tool") and enfant:GetAttribute(Reglages.ATTRIBUT_OUTIL) == id then
						return true
					end
				end
			end
		end
		return false
	end

	-- Fabrique l'outil, le met dans le Backpack et une copie dans StarterGear
	-- (StarterGear : le joueur le retrouve après une mort / un respawn).
	local function donnerOutil(joueur: Player, definition: Types.DefinitionOutil, objetDecor: Instance?): boolean
		local outil = fabrique.creer(definition, objetDecor)
		if not outil then
			return false
		end
		local sac = joueur:FindFirstChildOfClass("Backpack")
		local equipementDepart = joueur:FindFirstChild("StarterGear")
		-- copie pour StarterGear, faite avant de placer l'original (pas de souci d'état)
		if equipementDepart then
			outil:Clone().Parent = equipementDepart
		end
		if sac then
			outil.Parent = sac
		elseif not equipementDepart then
			outil:Destroy()
			return false
		else
			-- pas encore de Backpack : StarterGear suffit, il sera copié dans le Backpack au spawn (non vérifié)
			outil:Destroy()
		end
		return true
	end

	-- Premier objet du décor qui propose cet outil (sert de modèle de forme si pas de Tool dans ServerStorage).
	local function trouverObjetSource(definition: Types.DefinitionOutil): Instance?
		for _, objet in CollectionService:GetTagged(Reglages.TAG_RAMASSABLE) do
			if objet:GetAttribute(Reglages.ATTRIBUT_OUTIL) == definition.id then
				return objet
			end
		end
		return nil
	end

	-- Cas payant. Peut attendre (possede appelle Marketplace) : l'appelant protège avec enCours.
	local function traiterPayant(joueur: Player, definition: Types.DefinitionOutil, objet: Instance)
		local possedeLePasse = paiement.possede(joueur, definition)
		if joueur.Parent == nil then
			return -- parti pendant l'attente
		end
		if possedeLePasse then
			-- objet du décor jamais détruit : chaque acheteur a le sien
			local source: Instance? = if objet.Parent then objet else nil
			if donnerOutil(joueur, definition, source) then
				repondre(joueur, "ramasse", definition.id)
			else
				repondre(joueur, "indisponible", definition.id)
			end
			return
		end
		local ok, code = paiement.proposerAchat(joueur, definition)
		if ok then
			repondre(joueur, "achat_propose", definition.id)
		else
			repondre(joueur, code or "achat_indisponible", definition.id)
		end
	end

	local function surDemandeRamassage(joueur: Player, objet: unknown)
		if not limite.consommer(joueur) then
			return
		end
		if not validation.estObjetTagueValide(objet, Reglages.TAG_RAMASSABLE) then
			return
		end
		local cible = objet :: Instance
		local definition = DefinitionsOutils.obtenir(cible:GetAttribute(Reglages.ATTRIBUT_OUTIL))
		if not definition then
			return
		end
		if reserves[cible] then
			repondre(joueur, "indisponible", definition.id)
			return
		end
		local personnage = validation.personnageVivant(joueur)
		if not personnage then
			return
		end
		if not validation.aPortee(joueur, cible, Reglages.PORTEE_RAMASSAGE) then
			repondre(joueur, "trop_loin", definition.id)
			return
		end
		if not validation.voit(joueur, cible) then
			repondre(joueur, "pas_visible", definition.id)
			return
		end
		if possedeDeja(joueur, definition.id) then
			repondre(joueur, "deja_possede", definition.id)
			return
		end

		if not definition.payant then
			-- Gratuit : on réserve l'objet AVANT toute attente pour qu'un seul joueur le prenne
			reserves[cible] = true
			if not donnerOutil(joueur, definition, cible) then
				reserves[cible] = nil
				repondre(joueur, "indisponible", definition.id)
				return
			end
			if cible:GetAttribute(Reglages.ATTRIBUT_PERMANENT) ~= true then
				cible:Destroy()
			end
			reserves[cible] = nil
			repondre(joueur, "ramasse", definition.id)
			return
		end

		-- Payant : un seul traitement à la fois par joueur
		if enCours[joueur] then
			return
		end
		enCours[joueur] = true
		local ok, erreur = pcall(traiterPayant, joueur, definition, cible)
		enCours[joueur] = nil -- toujours libéré, même après une erreur
		if not ok then
			warn("ServiceRamassage : erreur pendant l'achat de " .. definition.id .. " : " .. tostring(erreur))
			if joueur.Parent then
				repondre(joueur, "indisponible", definition.id)
			end
		end
	end

	remotes.DemanderRamassage.OnServerEvent:Connect(surDemandeRamassage)

	paiement.surAchatConfirme(function(joueur: Player, definition: Types.DefinitionOutil)
		if joueur.Parent == nil then
			return
		end
		if possedeDeja(joueur, definition.id) then
			repondre(joueur, "deja_possede", definition.id)
			return
		end
		if donnerOutil(joueur, definition, trouverObjetSource(definition)) then
			repondre(joueur, "achete", definition.id)
		else
			warn("ServiceRamassage : achat confirmé mais outil impossible à donner : " .. definition.id)
			repondre(joueur, "indisponible", definition.id)
		end
	end)

	paiement.surAchatAnnule(function(joueur: Player, definition: Types.DefinitionOutil)
		if joueur.Parent then
			repondre(joueur, "achat_annule", definition.id)
		end
	end)

	-- Reconnexion : redonner les outils payants déjà possédés.
	-- On attend le Backpack (jusqu'à ATTENTE_BACKPACK s). S'il n'existe pas encore (le personnage
	-- n'est pas apparu), donnerOutil met quand même l'outil dans StarterGear, qui est copié dans
	-- le Backpack au spawn (ordre exact StarterGear/Backpack : non vérifié).
	local function redonnerOutilsPayes(joueur: Player)
		joueur:WaitForChild("Backpack", ATTENTE_BACKPACK)
		for _, definition in DefinitionsOutils.Definitions do
			if joueur.Parent == nil then
				return
			end
			if definition.payant and definition.idGamePass ~= 0 and not possedeDeja(joueur, definition.id) then
				if paiement.possede(joueur, definition) and joueur.Parent and not possedeDeja(joueur, definition.id) then
					donnerOutil(joueur, definition, trouverObjetSource(definition))
				end
			end
		end
	end

	Players.PlayerAdded:Connect(function(joueur: Player)
		task.spawn(redonnerOutilsPayes, joueur)
	end)
	for _, joueur in Players:GetPlayers() do
		task.spawn(redonnerOutilsPayes, joueur)
	end

	Players.PlayerRemoving:Connect(function(joueur: Player)
		limite.oublier(joueur)
		enCours[joueur] = nil
	end)
end

return ServiceRamassage
