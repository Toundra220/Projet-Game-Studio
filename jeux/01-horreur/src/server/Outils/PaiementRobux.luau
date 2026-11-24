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
	Date    : 2026-11-24
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local DefinitionsOutils = require(Partage:WaitForChild("DefinitionsOutils"))

local PaiementRobux = {}

function PaiementRobux.nouveau(): Types.Paiement
	-- cache[joueur][idOutil] = true quand on sait que le joueur possède le game pass
	local cache: { [Player]: { [string]: boolean } } = {}
	-- un seul achat proposé à la fois par joueur
	local enAttente: { [Player]: Types.DefinitionOutil } = {}
	local rappelsConfirme: { Types.RappelAchat } = {}
	local rappelsAnnule: { Types.RappelAchat } = {}

	local function possede(joueur: Player, definition: Types.DefinitionOutil): boolean
		if definition.idGamePass == 0 then
			return false
		end
		local cacheJoueur = cache[joueur]
		if cacheJoueur and cacheJoueur[definition.id] then
			return true
		end
		local ok, resultat = pcall(
			MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService,
			joueur.UserId,
			definition.idGamePass
		)
		if not ok then
			-- erreur réseau/Roblox : on ne met rien en cache, on réessaiera au prochain appel
			warn("PaiementRobux : UserOwnsGamePassAsync a échoué pour " .. definition.id .. " : " .. tostring(resultat))
			return false
		end
		if resultat == true then
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
			warn("PaiementRobux : ID du game pass à remplir dans DefinitionsOutils (" .. definition.id .. ")")
			return false, "achat_indisponible"
		end
		-- anti-doublon : la fenêtre est déjà ouverte, on ne la rouvre pas (pas une erreur)
		if enAttente[joueur] then
			return true
		end
		enAttente[joueur] = definition
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
		enAttente[joueur] = nil
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
