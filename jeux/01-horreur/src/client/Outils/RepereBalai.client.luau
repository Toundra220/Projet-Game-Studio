--!strict
--[[
	Rôle    : au début de la partie, montre le balai à travers les murs (Highlight AlwaysOnTop,
	          style chaud et discret comme AffichageCible) avec un petit texte « Prends le balai ».
	          Tout est local : les autres joueurs ne voient rien. Le repère disparaît dès que le joueur
	          a le balai (Backpack ou main) et revient s'il le perd. Il est séparé de la surbrillance
	          d'AffichageCible (« SurbrillanceOutil », mode Occluded) qu'il ne touche pas.
	          Le texte se cache quand le joueur est tout près : « [E] Ramasser le balai » prend le relais.
	          Le client ne décide rien : le ramassage reste vérifié par le serveur.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Definitions = require(Partage:WaitForChild("DefinitionsOutils"))
local LigneDeVue = require(Partage:WaitForChild("LigneDeVue"))

local Reglages = Definitions.Reglages
local joueur = Players.LocalPlayer

local PERIODE = 0.25                -- secondes entre deux vérifications
local DISTANCE_TEXTE_MIN = 10       -- plus près : on cache le texte (l'étiquette de ramassage s'affiche)
local TEXTE = "Prends le balai"

-- Mêmes teintes chaudes qu'AffichageCible, un peu plus discrètes
local COULEUR_REMPLISSAGE = Color3.fromRGB(255, 190, 110)
local COULEUR_CONTOUR = Color3.fromRGB(255, 226, 170)
local COULEUR_FOND = Color3.fromRGB(20, 14, 10)
local COULEUR_TEXTE = Color3.fromRGB(255, 236, 205)

local repere: Highlight? = nil
local etiquette: BillboardGui? = nil

local function aLOutil(id: string): boolean
	local sac = joueur:FindFirstChildOfClass("Backpack")
	for _, conteneur in { sac, joueur.Character } do
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

-- Le balai du décor : un objet « Ramassable » portant l'outil de départ
local function trouverBalai(): Instance?
	for _, objet in CollectionService:GetTagged(Reglages.TAG_RAMASSABLE) do
		if objet:GetAttribute(Reglages.ATTRIBUT_OUTIL) == Reglages.OUTIL_DE_DEPART and objet:IsDescendantOf(workspace) then
			return objet
		end
	end
	return nil
end

local function creerRepere(): Highlight
	local h = Instance.new("Highlight")
	h.Name = "RepereBalai"
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- visible à travers les murs
	h.FillColor = COULEUR_REMPLISSAGE
	h.FillTransparency = 0.65
	h.OutlineColor = COULEUR_CONTOUR
	h.OutlineTransparency = 0.15
	return h
end

local function creerEtiquette(): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RepereBalaiTexte"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Size = UDim2.fromOffset(170, 30)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local texte = Instance.new("TextLabel")
	texte.Name = "Texte"
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundColor3 = COULEUR_FOND
	texte.BackgroundTransparency = 0.45
	texte.TextColor3 = COULEUR_TEXTE
	texte.Font = Enum.Font.GothamMedium
	texte.TextScaled = true
	texte.Text = TEXTE
	texte.Parent = billboard

	local coins = Instance.new("UICorner")
	coins.CornerRadius = UDim.new(0, 8)
	coins.Parent = texte
	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 4)
	marge.PaddingBottom = UDim.new(0, 4)
	marge.PaddingLeft = UDim.new(0, 8)
	marge.PaddingRight = UDim.new(0, 8)
	marge.Parent = texte
	return billboard
end

local function cacher()
	if repere then
		repere.Adornee = nil
		repere.Parent = nil
	end
	if etiquette then
		etiquette.Enabled = false
		etiquette.Adornee = nil
	end
end

local function montrer(balai: Instance)
	if not repere or repere.Parent == nil or repere.Adornee ~= balai then
		if repere then
			repere:Destroy()
		end
		repere = creerRepere()
	end
	local h = repere :: Highlight
	if h.Adornee ~= balai then
		h.Adornee = balai
		h.Parent = balai
	end

	if not etiquette then
		etiquette = creerEtiquette()
	end
	local e = etiquette :: BillboardGui
	local interface = joueur:FindFirstChildOfClass("PlayerGui")
	if interface and e.Parent ~= interface then
		e.Parent = interface
	end
	local partie = LigneDeVue.partieAffichage(balai)
	e.Adornee = partie

	local perso = joueur.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	local proche = false
	if partie and racine and racine:IsA("BasePart") then
		proche = (partie.Position - racine.Position).Magnitude < DISTANCE_TEXTE_MIN
	end
	e.Enabled = partie ~= nil and not proche
end

task.spawn(function()
	while true do
		local balai = trouverBalai()
		-- pendant un respawn le Backpack est vide un instant : on n'affiche rien tant que le joueur n'est pas vivant
		local perso = joueur.Character
		local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
		local vivant = humanoide ~= nil and humanoide.Health > 0
		if balai and vivant and not aLOutil(Reglages.OUTIL_DE_DEPART) then
			montrer(balai)
		else
			cacher()
		end
		task.wait(PERIODE)
	end
end)
