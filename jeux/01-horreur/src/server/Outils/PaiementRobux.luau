--!strict
--[[
	Rôle    : paiement en Robux d'un outil, via un GAME PASS.
	          Pourquoi un game pass : c'est un achat unique et permanent, donc l'outil
	          est gardé pour toujours (Roblox retient lui-même que le joueur le possède).
	          Un developer product serait consommable : il faudrait gérer ProcessReceipt
	          et sauvegarder nous-mêmes l'achat (DataStore).
	          Tout se passe côté serveur ; le client ne fait que voir la fenêtre Roblox.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24 (modifié : 2026-11-26, ID à 0 = code « achat_non_configure », fenêtre
	          d'achat qui expire, revérification d'un achat que le serveur n'a pas proposé)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local DefinitionsOutils = require(Partage:WaitForChild("DefinitionsOutils"))

local PaiementRobux = {}

-- Une fenêtre d'achat dont on n'a jamais reçu la fin (fermeture ratée côté client) ne bloque
-- pas le joueur pour toujours : au-delà de ce délai, on peut la rouvrir.
local DELAI_FENETRE_ACHAT = 60 -- secondes

type Attente = { definition: Types.DefinitionOutil, depuis: number }

function PaiementRobux.nouveau(): Types.Paiement
	-- cache[joueur][idOutil] = true quand on sait que le joueur possède le game pass
	local cache: { [Player]: { [string]: boolean } } = {}
	-- un seul achat proposé à la fois par joueur (et à quel moment)
	local enAttente: { [Player]: Attente } = {}
	local rappelsConfirme: { Types.RappelAchat } = {}
	local rappelsAnnule: { Types.RappelAchat } = {}
	local dejaSignale: { [string]: boolean } = {} -- avertissement « ID à 0 » une seule fois par outil

	-- Demande à Roblox (sans le cache) : le joueur possède-t-il le game pass ? false en cas d'erreur.
	local function demanderARoblox(joueur: Player, definition: Types.DefinitionOutil): boolean
		local ok, resultat = pcall(
			MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService,
			joueur.UserId,
			definition.idGamePass
		)
		if not ok then
			warn("PaiementRobux : UserOwnsGamePassAsync a échoué pour " .. definition.id .. " : " .. tostring(resultat))
			return false
		end
		return resultat == true
	end

	local function possede(joueur: Player, definition: Types.DefinitionOutil): boolean
		if definition.idGamePass == 0 then
			return false
		end
		local cacheJoueur = cache[joueur]
		if cacheJoueur and cacheJoueur[definition.id] then
			return true
		end
		-- erreur réseau/Roblox : false, rien en cache, on réessaiera au prochain appel
		if demanderARoblox(joueur, definition) then
			if joueur.Parent == nil then
				return false -- parti pendant l'attente : pas d'entrée orpheline dans le cache
			end
			if not cache[joueur] then
				cache[joueur] = {}
			end
			cache[joueur][definition.id] = true
			return true
		end
		return false
	end

	local function proposerAchat(joueur: Player, definition: Types.DefinitionOutil): (boolean, string?)
		if definition.idGamePass == 0 then
			-- game pass pas encore créé : message clair au joueur, avertissement unique pour Romain
			if not dejaSignale[definition.id] then
				dejaSignale[definition.id] = true
				warn("PaiementRobux : idGamePass = 0 pour « " .. definition.id .. " ». Crée le game pass "
					.. "(Creator Hub) et mets son ID dans DefinitionsOutils. En attendant, l'achat est refusé.")
			end
			return false, "achat_non_configure"
		end
		-- anti-doublon : la fenêtre est déjà ouverte, on ne la rouvre pas (pas une erreur)
		local attente = enAttente[joueur]
		if attente and os.clock() - attente.depuis < DELAI_FENETRE_ACHAT then
			return true
		end
		enAttente[joueur] = { definition = definition, depuis = os.clock() }
		local ok, erreur = pcall(
			MarketplaceService.PromptGamePassPurchase,
			MarketplaceService,
			joueur,
			definition.idGamePass
		)
		if not ok then
			enAttente[joueur] = nil
			warn("PaiementRobux : PromptGamePassPurchase a échoué : " .. tostring(erreur))
			return false, "achat_indisponible"
		end
		return true
	end

	local function surAchatConfirme(rappel: Types.RappelAchat)
		table.insert(rappelsConfirme, rappel)
	end

	local function surAchatAnnule(rappel: Types.RappelAchat)
		table.insert(rappelsAnnule, rappel)
	end

	-- Définition payante correspondant à ce game pass (ignore les ID à 0).
	local function trouverDefinition(idPasse: number): Types.DefinitionOutil?
		if idPasse == 0 then
			return nil
		end
		for _, definition in DefinitionsOutils.Definitions do
			if definition.payant and definition.idGamePass == idPasse then
				return definition
			end
		end
		return nil
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(joueur: Player, idPasse: number, achete: boolean)
		local definition = trouverDefinition(idPasse)
		if not definition then
			return -- un autre game pass (pas le nôtre)
		end
		local attente = enAttente[joueur]
		local proposeParLeServeur = attente ~= nil and attente.definition == definition
		enAttente[joueur] = nil
		if achete and not proposeParLeServeur then
			-- Fenêtre que le serveur n'a pas ouverte : on ne croit pas l'événement seul,
			-- on redemande à Roblox avant de donner l'outil (prudence, voir rapport : non vérifié
			-- qu'un client puisse fausser cet événement, mais ça ne coûte qu'un appel).
			achete = demanderARoblox(joueur, definition)
			if joueur.Parent == nil then
				return
			end
		end
		if achete then
			if not cache[joueur] then
				cache[joueur] = {}
			end
			cache[joueur][definition.id] = true
		end
		for _, rappel in (if achete then rappelsConfirme else rappelsAnnule) do
			task.spawn(rappel, joueur, definition)
		end
	end)

	Players.PlayerRemoving:Connect(function(joueur: Player)
		cache[joueur] = nil
		enAttente[joueur] = nil
	end)

	return {
		nom = "Robux (game pass)",
		possede = possede,
		proposerAchat = proposerAchat,
		surAchatConfirme = surAchatConfirme,
		surAchatAnnule = surAchatAnnule,
	}
end

return PaiementRobux
