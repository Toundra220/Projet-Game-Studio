--[[
	Rôle    : racine de composition du niveau de bruit côté serveur : trouve (ou crée) les
	          BindableEvent du serveur, puis démarre ServiceBruit. Aucune logique ici.
	          MonstreBruit et OutilDonne sont dans ServerStorage : le client ne peut ni les voir
	          ni les déclencher. Chiffres : Shared/Bruit/ReglagesBruit.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared")
local ReglagesBruit = require(Partage:WaitForChild("Bruit"):WaitForChild("ReglagesBruit"))
-- lecture seule : le nom de l'attribut que le serveur pose sur un outil pendant un nettoyage
local ReglagesOutils = require(Partage:WaitForChild("Outils"):WaitForChild("DefinitionsOutils")).Reglages
local ServiceBruit = require(script.Parent:WaitForChild("ServiceBruit"))

-- Trouver ou créer, sans attente entre les deux (même motif que MonstreIA et Outils/EvenementsServeur)
local function evenementServeur(nom: string): BindableEvent
	local existant = ServerStorage:FindFirstChild(nom)
	if existant and existant:IsA("BindableEvent") then
		return existant
	end
	local evenement = Instance.new("BindableEvent")
	evenement.Name = nom
	evenement.Parent = ServerStorage
	return evenement
end

ServiceBruit.demarrer({
	reglages = ReglagesBruit,
	evenementBruit = evenementServeur("MonstreBruit"),
	evenementOutil = evenementServeur("OutilDonne"),
	attributEnUtilisation = ReglagesOutils.ATTRIBUT_EN_UTILISATION,
})
