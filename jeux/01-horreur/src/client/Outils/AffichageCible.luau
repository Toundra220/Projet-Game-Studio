--!strict
--[[
	Rôle    : montre au joueur l'objet visé : contour (Highlight) + petite étiquette de texte
	          (BillboardGui). Un seul Highlight et un seul BillboardGui sont créés et réutilisés.
	          Le Highlight est en mode « Occluded » : il n'est jamais visible à travers un mur.
	          Tout est local (non répliqué) : les autres joueurs ne voient rien.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local LigneDeVue = require(Partage:WaitForChild("LigneDeVue"))

-- Couleurs chaudes et discrètes (ambiance manoir)
local COULEUR_REMPLISSAGE = Color3.fromRGB(255, 190, 110)
local COULEUR_CONTOUR = Color3.fromRGB(255, 226, 170)
local COULEUR_FOND = Color3.fromRGB(20, 14, 10)
local COULEUR_TEXTE = Color3.fromRGB(255, 236, 205)

local DISTANCE_MAX_ETIQUETTE = 25
local TAILLE_ETIQUETTE = UDim2.fromOffset(260, 44)
local DECALAGE_ETIQUETTE = Vector3.new(0, 1.5, 0)

local AffichageCible = {}

local function creerHighlight(): Highlight
	local surbrillance = Instance.new("Highlight")
	surbrillance.Name = "SurbrillanceOutil"
	surbrillance.DepthMode = Enum.HighlightDepthMode.Occluded -- essentiel : pas à travers les murs
	surbrillance.FillColor = COULEUR_REMPLISSAGE
	surbrillance.FillTransparency = 0.8
	surbrillance.OutlineColor = COULEUR_CONTOUR
	surbrillance.OutlineTransparency = 0
	return surbrillance
end

local function creerEtiquette(): (BillboardGui, TextLabel)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EtiquetteOutil"
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = DISTANCE_MAX_ETIQUETTE
	billboard.Size = TAILLE_ETIQUETTE
	billboard.StudsOffsetWorldSpace = DECALAGE_ETIQUETTE
	billboard.LightInfluence = 0
	billboard.Enabled = false
	-- ResetOnSpawn (propriété de LayerCollector) : sinon l'étiquette serait détruite à chaque
	-- respawn et ne pourrait plus être réutilisée
	billboard.ResetOnSpawn = false

	local texte = Instance.new("TextLabel")
	texte.Name = "Texte"
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundColor3 = COULEUR_FOND
	texte.BackgroundTransparency = 0.35
	texte.TextColor3 = COULEUR_TEXTE
	texte.Font = Enum.Font.GothamMedium
	texte.TextScaled = true
	texte.Text = ""
	texte.Parent = billboard

	local coins = Instance.new("UICorner")
	coins.CornerRadius = UDim.new(0, 8)
	coins.Parent = texte

	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 6)
	marge.PaddingBottom = UDim.new(0, 6)
	marge.PaddingLeft = UDim.new(0, 10)
	marge.PaddingRight = UDim.new(0, 10)
	marge.Parent = texte

	return billboard, texte
end

function AffichageCible.nouveau(): Types.Affichage
	local joueur = Players.LocalPlayer
	local surbrillance = creerHighlight()
	local billboard, texte = creerEtiquette()
	local detruit = false

	-- Un BillboardGui directement dans PlayerGui : on ne suppose pas qu'il survit au respawn
	-- (non vérifié). On le remet dans PlayerGui à chaque affichage s'il en est sorti.
	local function placerEtiquette()
		local interface = joueur:FindFirstChildOfClass("PlayerGui")
		if interface and billboard.Parent ~= interface then
			billboard.Parent = interface
		end
	end

	local function afficher(cible: Instance, message: string)
		if detruit then
			return
		end
		-- Si l'ancienne cible a été détruite (objet ramassé), le Highlight l'a été avec :
		-- on en recrée un (un Highlight détruit ne peut plus être réutilisé).
		local ok = pcall(function()
			surbrillance.Adornee = cible
			surbrillance.Parent = cible
		end)
		if not ok then
			surbrillance = creerHighlight()
			surbrillance.Adornee = cible
			surbrillance.Parent = cible
		end

		placerEtiquette()
		billboard.Adornee = LigneDeVue.partieAffichage(cible)
		texte.Text = message
		billboard.Enabled = billboard.Adornee ~= nil
	end

	local function masquer()
		billboard.Adornee = nil
		billboard.Enabled = false
		pcall(function()
			surbrillance.Adornee = nil
			surbrillance.Parent = nil
		end)
	end

	local function detruire()
		detruit = true
		billboard:Destroy()
		surbrillance:Destroy()
	end

	return { afficher = afficher, masquer = masquer, detruire = detruire }
end

return AffichageCible
