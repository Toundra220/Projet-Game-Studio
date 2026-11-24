--!strict
--[[
	Rôle    : utilisation de l'outil équipé par le joueur local (clic maintenu).
	          - détecte la cible visible (DetecteurVisibilite) et l'affiche avec sa progression
	          - clic maintenu (Activated) -> demande « debut » au serveur ; relâché -> « arret »
	          Le client ne fait que DEMANDER : le serveur décide de la durée, de la validité
	          et du résultat. L'animation est gérée ailleurs (AnimationOutils.client).
	          La notification de fin n'est pas affichée ici (c'est Ramassage.client qui le fait).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Definitions = require(Partage:WaitForChild("DefinitionsOutils") :: ModuleScript)
local Remotes = require(Partage:WaitForChild("Remotes") :: ModuleScript)
local Types = require(Partage:WaitForChild("Types") :: ModuleScript)
local DetecteurVisibilite = require(script.Parent:WaitForChild("DetecteurVisibilite") :: ModuleScript)
local AffichageCible = require(script.Parent:WaitForChild("AffichageCible") :: ModuleScript)

type DefinitionOutil = Types.DefinitionOutil

local Reglages = Definitions.Reglages
local joueurLocal = Players.LocalPlayer
local remotes = Remotes.obtenir()
local affichage = AffichageCible.nouveau() -- un seul affichage pour tout le script

-- ===== État de l'outil équipé =====
local outilCourant: Tool? = nil
local appuye = false                       -- le bouton est maintenu
local derniereCibleDemandee: Instance? = nil
local generationOutil = 0                  -- change à chaque (dé)équipement : arrête la boucle
local connexionsOutil: { RBXScriptConnection } = {}

-- ===== État du personnage =====
local generationPerso = 0
local connexionsPerso: { RBXScriptConnection } = {}
local persoCourant: Model? = nil

local function deconnecter(liste: { RBXScriptConnection })
	for _, c in liste do
		c:Disconnect()
	end
	table.clear(liste)
end

-- Déséquipement, mort ou changement de personnage : on prévient le serveur et on nettoie
local function arreterOutil()
	generationOutil += 1 -- la boucle en cours s'arrête à son prochain tour
	deconnecter(connexionsOutil)
	if derniereCibleDemandee then
		remotes.DemanderUtilisation:FireServer("arret")
	end
	derniereCibleDemandee = nil
	appuye = false
	outilCourant = nil
	affichage.masquer()
end

local function pourcentage(cible: Instance): number
	local p = cible:GetAttribute(Reglages.ATTRIBUT_PROGRESSION)
	if type(p) ~= "number" then
		return 0
	end
	return math.floor(math.clamp(p, 0, 1) * 100 + 0.5)
end

local function equiper(tool: Tool)
	if tool == outilCourant then
		return
	end
	local definition = Definitions.obtenir(tool:GetAttribute(Reglages.ATTRIBUT_OUTIL))
	if not definition then
		return -- outil sans définition (lampe, etc.) : pas notre affaire
	end
	arreterOutil() -- au cas où un autre outil était considéré comme équipé

	outilCourant = tool
	appuye = false
	derniereCibleDemandee = nil
	local maGeneration = generationOutil
	local def: DefinitionOutil = definition

	table.insert(connexionsOutil, tool.Activated:Connect(function()
		appuye = true
	end))
	table.insert(connexionsOutil, tool.Deactivated:Connect(function()
		appuye = false
	end))

	local detecteur = DetecteurVisibilite.nouveau({
		tag = def.tagCible,
		portee = def.porteeUtilisation,
		demiAngle = Reglages.DEMI_ANGLE_CIBLAGE,
		-- on ignore ce qui est déjà propre, et ce qui exige un autre outil
		filtre = function(objet: Instance): boolean
			if objet:GetAttribute(Reglages.ATTRIBUT_NETTOYE) == true then
				return false
			end
			local requis = objet:GetAttribute(Reglages.ATTRIBUT_OUTIL_REQUIS)
			return requis == nil or requis == def.id
		end,
	})

	task.spawn(function()
		while generationOutil == maGeneration do
			local cible = detecteur.chercher()
			if generationOutil ~= maGeneration then
				break
			end

			if cible then
				affichage.afficher(cible, "Maintenir clic : " .. def.verbeUtilisation
					.. " (" .. pourcentage(cible) .. " %)")
			else
				affichage.masquer()
			end

			-- Anti-spam : « debut » n'est renvoyé que si la cible change ou après un
			-- relâchement (pas de renvoi en boucle si le serveur a refusé).
			if appuye and cible and cible ~= derniereCibleDemandee then
				remotes.DemanderUtilisation:FireServer("debut", cible)
				derniereCibleDemandee = cible
			elseif (not appuye or cible == nil) and derniereCibleDemandee then
				remotes.DemanderUtilisation:FireServer("arret")
				derniereCibleDemandee = nil
			end

			task.wait(Reglages.PERIODE_DETECTION)
		end
	end)
end

-- Un « utilisation_fini » du serveur n'appelle aucune réponse : la cible nettoyée
-- porte l'attribut Nettoye, le filtre du détecteur l'écarte, et la boucle envoie « arret ».

local function lierPersonnage(personnage: Model)
	-- Garde avant le nettoyage : un appel périmé ne doit pas défaire une liaison actuelle
	if joueurLocal.Character ~= personnage or persoCourant == personnage then
		return
	end
	-- nettoyage de l'ancien personnage
	generationPerso += 1
	arreterOutil()
	deconnecter(connexionsPerso)
	persoCourant = personnage
	local maGeneration = generationPerso

	local humanoide = personnage:WaitForChild("Humanoid", 10)
	-- un respawn pendant l'attente rend cet appel périmé
	if generationPerso ~= maGeneration or not humanoide or not humanoide:IsA("Humanoid") then
		return
	end

	table.insert(connexionsPerso, humanoide.Died:Connect(function()
		if generationPerso == maGeneration then
			arreterOutil()
		end
	end))
	table.insert(connexionsPerso, personnage.ChildAdded:Connect(function(enfant: Instance)
		if generationPerso == maGeneration and enfant:IsA("Tool") then
			equiper(enfant)
		end
	end))
	table.insert(connexionsPerso, personnage.ChildRemoved:Connect(function(enfant: Instance)
		if generationPerso == maGeneration and enfant == outilCourant then
			arreterOutil()
		end
	end))

	-- outil déjà dans les mains à la création de la liaison
	local deja = personnage:FindFirstChildOfClass("Tool")
	if deja then
		equiper(deja)
	end
end

joueurLocal.CharacterRemoving:Connect(function(personnage: Model)
	if persoCourant == personnage then
		generationPerso += 1
		arreterOutil()
		deconnecter(connexionsPerso)
		persoCourant = nil
	end
end)
joueurLocal.CharacterAdded:Connect(lierPersonnage)
if joueurLocal.Character then
	task.defer(lierPersonnage, joueurLocal.Character)
end
