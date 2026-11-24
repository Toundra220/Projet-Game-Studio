--!strict
--[[
	Rôle    : trouve l'objet (portant un tag) que le joueur regarde et peut atteindre.
	          Trois conditions, de la moins chère à la plus chère :
	          1. portée : l'objet est assez près de la tête du joueur ;
	          2. champ de vision : il est à l'écran et dans un cône autour du regard de la caméra ;
	          3. pas de mur : un rayon depuis la caméra ET un rayon depuis la tête arrivent à l'objet.
	          Le rayon depuis la tête est celui que le serveur refera : sans lui, le client
	          afficherait des objets que le serveur refuse. Le rayon depuis la caméra évite
	          d'afficher un objet à travers un mur en 3e personne.
	          Ce module ne décide rien : il sert seulement à l'affichage et à la demande.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local LigneDeVue = require(Partage:WaitForChild("LigneDeVue"))

local DetecteurVisibilite = {}

export type Options = {
	tag: string,
	portee: number,
	demiAngle: number,
	filtre: ((objet: Instance) -> boolean)?,
}

-- Un objet porté par un joueur (dans un Tool) ou faisant partie d'un personnage n'est pas ramassable.
local function estSurUnPersonnage(objet: Instance): boolean
	if objet:FindFirstAncestorOfClass("Tool") then
		return true
	end
	local modele = objet:FindFirstAncestorOfClass("Model")
	while modele do
		if modele:FindFirstChildOfClass("Humanoid") then
			return true
		end
		modele = modele:FindFirstAncestorOfClass("Model")
	end
	return false
end

function DetecteurVisibilite.nouveau(options: Options): Types.Detecteur
	local tag = options.tag
	local portee = options.portee
	local demiAngle = options.demiAngle
	local filtre = options.filtre

	local function chercher(): Instance?
		-- le joueur doit être vivant
		local perso = Players.LocalPlayer.Character
		if not perso then
			return nil
		end
		local humanoide = perso:FindFirstChildOfClass("Humanoid")
		if not humanoide or humanoide.Health <= 0 then
			return nil
		end
		local tete = perso:FindFirstChild("Head") or perso:FindFirstChild("HumanoidRootPart")
		if not tete or not tete:IsA("BasePart") then
			return nil
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end

		local posCamera = camera.CFrame.Position
		local regard = camera.CFrame.LookVector
		local posTete = tete.Position
		local exclus = LigneDeVue.personnagesJoueurs()

		local meilleur: Instance? = nil
		local meilleurAngle = math.huge

		for _, objet in CollectionService:GetTagged(tag) do
			if not objet:IsDescendantOf(workspace) or estSurUnPersonnage(objet) then
				continue
			end
			if filtre and not filtre(objet) then
				continue
			end
			local point = LigneDeVue.pointCentral(objet)
			if not point then
				continue
			end

			-- 1. portée (du moins cher au plus cher)
			if LigneDeVue.distance(objet, posTete) > portee then
				continue
			end

			-- 2. champ de vision : à l'écran, devant la caméra, dans le cône
			local ecran, aLEcran = camera:WorldToViewportPoint(point)
			if not aLEcran or ecran.Z <= 0 then
				continue
			end
			local versObjet = point - posCamera
			local angle = 0 -- objet pile sur la caméra : on le considère en plein centre
			if versObjet.Magnitude > 1e-3 then
				angle = math.acos(math.clamp(regard:Dot(versObjet.Unit), -1, 1))
			end
			if angle > demiAngle or angle >= meilleurAngle then
				continue
			end

			-- 3. pas de mur : rayon caméra puis rayon tête (les plus chers, en dernier)
			if not LigneDeVue.visibleDepuis(posCamera, objet, exclus) then
				continue
			end
			if not LigneDeVue.visibleDepuis(posTete, objet, exclus) then
				continue
			end

			meilleur = objet
			meilleurAngle = angle
		end

		return meilleur
	end

	return { chercher = chercher }
end

return DetecteurVisibilite
