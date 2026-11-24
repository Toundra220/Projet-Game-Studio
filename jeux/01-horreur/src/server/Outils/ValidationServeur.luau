--!strict
--[[
	Rôle    : vérifications côté serveur partagées par le ramassage et l'utilisation
	          (joueur vivant, objet valide, portée, ligne de vue, outil équipé).
	          Le client n'envoie que des intentions : tout est revérifié ici.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local DefinitionsOutils = require(Partage:WaitForChild("DefinitionsOutils"))
local LigneDeVue = require(Partage:WaitForChild("LigneDeVue"))

local Reglages = DefinitionsOutils.Reglages

local HAUTEUR_YEUX_SANS_TETE = 1.5 -- au dessus du HumanoidRootPart, si le personnage n'a pas de tête

local ValidationServeur = {}

-- Personnage vivant du joueur, et sa tête (sinon son HumanoidRootPart).
function ValidationServeur.personnageVivant(joueur: Player): (Model?, BasePart?)
	local personnage = joueur.Character
	if not personnage then
		return nil, nil
	end
	local humanoide = personnage:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 then
		return nil, nil
	end
	local tete = personnage:FindFirstChild("Head")
	if tete and tete:IsA("BasePart") then
		return personnage, tete
	end
	local racine = personnage:FindFirstChild("HumanoidRootPart")
	if racine and racine:IsA("BasePart") then
		return personnage, racine
	end
	return nil, nil
end

-- Position des yeux : la tête, sinon le HumanoidRootPart relevé de 1,5 stud.
function ValidationServeur.positionYeux(joueur: Player): Vector3?
	local personnage, partie = ValidationServeur.personnageVivant(joueur)
	if not personnage or not partie then
		return nil
	end
	if partie.Name == "Head" then
		return partie.Position
	end
	return partie.Position + Vector3.new(0, HAUTEUR_YEUX_SANS_TETE, 0)
end

-- L'objet reçu du client est-il bien une Instance du décor portant ce tag ?
-- (un exploiteur peut envoyer n'importe quoi : nil, nombre, table, personnage...)
function ValidationServeur.estObjetTagueValide(objet: unknown, tag: string): boolean
	if typeof(objet) ~= "Instance" then
		return false
	end
	local instance = objet :: Instance
	if not CollectionService:HasTag(instance, tag) then
		return false
	end
	if not instance:IsDescendantOf(workspace) then
		return false
	end
	-- pas un objet déjà tenu en main (dans un Tool)
	if instance:FindFirstAncestorOfClass("Tool") then
		return false
	end
	-- pas une partie d'un personnage (joueur ou monstre) : on remonte les ancêtres
	local courant: Instance? = instance
	while courant and courant ~= workspace do
		if courant:IsA("Model") and courant:FindFirstChildOfClass("Humanoid") then
			return false
		end
		courant = courant.Parent
	end
	return true
end

-- Le joueur est-il assez près ? (portée de la définition + tolérance de latence)
function ValidationServeur.aPortee(joueur: Player, objet: Instance, portee: number): boolean
	local yeux = ValidationServeur.positionYeux(joueur)
	if not yeux then
		return false
	end
	return LigneDeVue.distance(objet, yeux) <= portee + Reglages.TOLERANCE_PORTEE
end

-- Le joueur voit-il l'objet depuis ses yeux (aucun mur entre les deux) ?
function ValidationServeur.voit(joueur: Player, objet: Instance): boolean
	local yeux = ValidationServeur.positionYeux(joueur)
	if not yeux then
		return false
	end
	return LigneDeVue.visibleDepuis(yeux, objet, LigneDeVue.personnagesJoueurs())
end

-- Outil actuellement en main (Tool enfant direct du personnage) et sa définition.
function ValidationServeur.outilEquipe(joueur: Player): (Tool?, Types.DefinitionOutil?)
	local personnage = joueur.Character
	if not personnage then
		return nil, nil
	end
	for _, enfant in personnage:GetChildren() do
		if enfant:IsA("Tool") then
			local definition = DefinitionsOutils.obtenir(enfant:GetAttribute(Reglages.ATTRIBUT_OUTIL))
			if definition then
				return enfant, definition
			end
		end
	end
	return nil, nil
end

return ValidationServeur
