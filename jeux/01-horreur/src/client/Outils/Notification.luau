--!strict
--[[
	Rôle    : affiche un court message en bas de l'écran (« Tu as ramassé le balai. »).
	          Une seule ScreenGui, créée au premier appel. Un nouveau message remplace
	          l'ancien. Un compteur de génération empêche un ancien délai d'effacer un
	          message plus récent.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DUREE_DEFAUT = 2.5
local DUREE_FONDU = 0.25
local INFO_FONDU = TweenInfo.new(DUREE_FONDU, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Notification = {}

local ecran: ScreenGui? = nil
local etiquette: TextLabel? = nil
local generation = 0
local tweenEnCours: Tween? = nil

local function creerInterface(): (ScreenGui, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "NotificationOutils"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 10

	local texte = Instance.new("TextLabel")
	texte.Name = "Message"
	texte.AnchorPoint = Vector2.new(0.5, 1)
	texte.Position = UDim2.new(0.5, 0, 0.85, 0)
	texte.Size = UDim2.fromScale(0.4, 0.07)
	texte.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
	texte.BackgroundTransparency = 1
	texte.TextTransparency = 1
	texte.TextColor3 = Color3.fromRGB(255, 236, 205)
	texte.Font = Enum.Font.GothamMedium
	texte.TextScaled = true
	texte.Text = ""
	texte.Parent = gui

	local contrainte = Instance.new("UISizeConstraint")
	contrainte.MinSize = Vector2.new(200, 32)
	contrainte.MaxSize = Vector2.new(560, 56)
	contrainte.Parent = texte

	local coins = Instance.new("UICorner")
	coins.CornerRadius = UDim.new(0, 8)
	coins.Parent = texte

	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 6)
	marge.PaddingBottom = UDim.new(0, 6)
	marge.PaddingLeft = UDim.new(0, 12)
	marge.PaddingRight = UDim.new(0, 12)
	marge.Parent = texte

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, texte
end

-- Fondu vers une transparence donnée (annule le fondu précédent)
local function fondu(texte: TextLabel, fondDest: number, texteDest: number)
	if tweenEnCours then
		tweenEnCours:Cancel()
	end
	local tween = TweenService:Create(texte, INFO_FONDU, {
		BackgroundTransparency = fondDest,
		TextTransparency = texteDest,
	})
	tweenEnCours = tween
	tween:Play()
end

function Notification.afficher(message: string, duree: number?)
	if message == "" then
		return
	end
	-- recrée l'interface si elle a disparu (ex. détruite)
	if not ecran or not etiquette or not ecran.Parent then
		ecran, etiquette = creerInterface()
	end
	local texte = etiquette :: TextLabel

	generation += 1
	local maGeneration = generation

	texte.Text = message
	fondu(texte, 0.35, 0)

	task.delay(duree or DUREE_DEFAUT, function()
		-- un message plus récent est arrivé : on ne touche à rien
		if maGeneration ~= generation then
			return
		end
		fondu(texte, 1, 1)
	end)
end

return Notification
