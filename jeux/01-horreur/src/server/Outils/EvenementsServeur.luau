--!strict
--[[
	Rôle    : fournit les BindableEvent serveur utilisés par les outils (nettoyage).
	          Les BindableEvent sont dans ServerStorage : le client ne peut pas les déclencher.
	          Signatures :
	            NettoyageProgression:Fire(joueur: Player, cible: Instance, progression: number (0..1), idOutil: string)
	            NettoyageTermine:Fire(joueur: Player, cible: Instance, idOutil: string)
	            MonstreBruit:Fire(position: Vector3, portee: number)   -- déjà écouté par MonstreIA
	          Le futur TaskManager écoutera NettoyageTermine (et NettoyageProgression pour une
	          barre de progression), sans qu'on ait à modifier le code des outils.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local ServerStorage = game:GetService("ServerStorage")

export type EvenementsServeur = {
	progression: BindableEvent,
	termine: BindableEvent,
	bruitMonstre: BindableEvent,
}

local NOM_PROGRESSION = "NettoyageProgression"
local NOM_TERMINE = "NettoyageTermine"
local NOM_BRUIT = "MonstreBruit"

local EvenementsServeur = {}

local cache: EvenementsServeur? = nil

-- Trouver ou créer, sans attente entre les deux (même motif que MonstreIA)
local function trouverOuCreer(nom: string): BindableEvent
	local existant = ServerStorage:FindFirstChild(nom)
	if existant and existant:IsA("BindableEvent") then
		return existant
	end
	local evenement = Instance.new("BindableEvent")
	evenement.Name = nom
	evenement.Parent = ServerStorage
	return evenement
end

function EvenementsServeur.obtenir(): EvenementsServeur
	if cache then
		return cache
	end
	local evenements: EvenementsServeur = {
		progression = trouverOuCreer(NOM_PROGRESSION),
		termine = trouverOuCreer(NOM_TERMINE),
		bruitMonstre = trouverOuCreer(NOM_BRUIT),
	}
	cache = evenements
	return evenements
end

return EvenementsServeur
