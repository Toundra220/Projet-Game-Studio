--!strict
--[[
	Rôle    : petit indicateur de bruit en BAS À DROITE de l'écran, façon barres de signal :
	          autant de crans que de stades (hors 0), qui s'allument jusqu'au stade courant, du
	          rouge sombre au rouge vif. Un libellé dessous (« Silencieux », « Discret »,
	          « Audible », « Bruyant », « BRUYANT »). Au stade maximum (nettoyage), l'indicateur est
	          complet et brille : halo et contour rouges qui respirent doucement (moins d'un
	          battement par seconde, jamais un clignotement). Si le joueur a demandé moins de
	          mouvement (GuiService.ReducedMotionEnabled), la lueur reste fixe.
	          - seulement des Frames, UICorner, UIStroke et un TextLabel : aucune image ;
	          - zones sûres (ScreenInsets = DeviceSafeInsets) ; sur écran tactile, il monte au dessus
	            du bouton Courir et du bouton de saut ; ResetOnSpawn = false ;
	          - il ne décide rien : on lui donne le stade (lu par Bruit.client dans l'attribut écrit
	            par le serveur). Chiffres, couleurs, libellés : Shared/Bruit/ReglagesBruit.
	          parent : PlayerGui en jeu (ou StarterGui pour un aperçu en Edit).
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MARGE_INTERNE = 10
local ECART_TEXTE = 6
local HAUTEUR_TEXTE = 18
local LARGEUR_MIN = 104

export type Indicateur = {
	afficher: (stade: number) -> (),
	stade: () -> number,
	detruire: () -> (),
}

local IndicateurBruit = {}

-- L'écran est-il surtout tactile ? (PreferredInput suit l'appareil principal du joueur)
local function estTactile(): boolean
	local ok, prefere = pcall(function()
		return (UserInputService :: any).PreferredInput
	end)
	if ok and prefere ~= nil then
		return prefere == Enum.PreferredInput.Touch
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function IndicateurBruit.nouveau(R: any, parent: Instance): Indicateur
	local nombre: number = R.STADE_MAX
	local largeurCrans = nombre * R.CRAN_LARGEUR + (nombre - 1) * R.CRAN_ECART
	local largeur = math.max(LARGEUR_MIN, largeurCrans + 2 * MARGE_INTERNE)
	local hauteur = MARGE_INTERNE + R.CRAN_HAUTEUR_MAX + ECART_TEXTE + HAUTEUR_TEXTE + MARGE_INTERNE - 2

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "IndicateurBruit"
	ecran.ResetOnSpawn = false
	ecran.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	ecran.DisplayOrder = 5 -- comme la jauge d'endurance, sous les messages (Notification : 10)

	local panneau = Instance.new("Frame")
	panneau.Name = "Indicateur"
	panneau.AnchorPoint = Vector2.new(1, 1)
	panneau.Size = UDim2.fromOffset(largeur, hauteur)
	panneau.BackgroundColor3 = R.COULEUR_FOND
	panneau.BackgroundTransparency = R.TRANSPARENCE_FOND
	panneau.BorderSizePixel = 0
	panneau.Parent = ecran

	local coins = Instance.new("UICorner")
	coins.CornerRadius = UDim.new(0, 10)
	coins.Parent = panneau

	-- contour : discret d'habitude, rouge et lumineux au stade maximum
	local contour = Instance.new("UIStroke")
	contour.Name = "Contour"
	contour.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	contour.Thickness = 1
	contour.Color = R.COULEUR_CRAN_ETEINT
	contour.Transparency = 0.5
	contour.Parent = panneau

	-- halo derrière le panneau : invisible sauf au stade maximum
	local lueur = Instance.new("Frame")
	lueur.Name = "Lueur"
	lueur.AnchorPoint = Vector2.new(0.5, 0.5)
	lueur.Position = UDim2.fromScale(0.5, 0.5)
	lueur.Size = UDim2.new(1, 10, 1, 10)
	lueur.BackgroundColor3 = R.COULEURS_CRANS[nombre]
	lueur.BackgroundTransparency = 1
	lueur.BorderSizePixel = 0
	lueur.ZIndex = 0
	lueur.Parent = panneau
	local coinsLueur = Instance.new("UICorner")
	coinsLueur.CornerRadius = UDim.new(0, 14)
	coinsLueur.Parent = lueur

	-- les crans : barres de plus en plus hautes, alignées en bas
	local zoneCrans = Instance.new("Frame")
	zoneCrans.Name = "Crans"
	zoneCrans.AnchorPoint = Vector2.new(0.5, 0)
	zoneCrans.Position = UDim2.new(0.5, 0, 0, MARGE_INTERNE)
	zoneCrans.Size = UDim2.fromOffset(largeurCrans, R.CRAN_HAUTEUR_MAX)
	zoneCrans.BackgroundTransparency = 1
	zoneCrans.ZIndex = 2
	zoneCrans.Parent = panneau

	local crans: { Frame } = {}
	for i = 1, nombre do
		local t = if nombre > 1 then (i - 1) / (nombre - 1) else 1
		local h = math.floor(R.CRAN_HAUTEUR_MIN + (R.CRAN_HAUTEUR_MAX - R.CRAN_HAUTEUR_MIN) * t + 0.5)
		local cran = Instance.new("Frame")
		cran.Name = "Cran" .. i
		cran.Position = UDim2.fromOffset((i - 1) * (R.CRAN_LARGEUR + R.CRAN_ECART), R.CRAN_HAUTEUR_MAX - h)
		cran.Size = UDim2.fromOffset(R.CRAN_LARGEUR, h)
		cran.BackgroundColor3 = R.COULEUR_CRAN_ETEINT
		cran.BackgroundTransparency = R.TRANSPARENCE_CRAN_ETEINT
		cran.BorderSizePixel = 0
		cran.ZIndex = 2
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 2)
		c.Parent = cran
		local trait = Instance.new("UIStroke")
		trait.Color = Color3.new(0, 0, 0)
		trait.Transparency = 0.55
		trait.Thickness = 1
		trait.Parent = cran
		cran.Parent = zoneCrans
		crans[i] = cran
	end

	local libelle = Instance.new("TextLabel")
	libelle.Name = "Libelle"
	libelle.AnchorPoint = Vector2.new(0.5, 1)
	libelle.Position = UDim2.new(0.5, 0, 1, -(MARGE_INTERNE - 2))
	libelle.Size = UDim2.new(1, -8, 0, HAUTEUR_TEXTE)
	libelle.BackgroundTransparency = 1
	libelle.Font = Enum.Font.GothamBold
	libelle.TextSize = R.TAILLE_TEXTE
	libelle.TextColor3 = R.COULEURS_TEXTE[1]
	libelle.TextStrokeColor3 = Color3.new(0, 0, 0)
	libelle.TextStrokeTransparency = 0.6
	libelle.Text = R.LIBELLES[1]
	libelle.ZIndex = 2
	libelle.Parent = panneau

	-- Placement : au dessus des boutons tactiles (Courir, saut) sur mobile, plus bas ailleurs
	local function placer()
		local bas = if estTactile() then R.DECALAGE_BAS_TACTILE else R.DECALAGE_BAS
		panneau.Position = UDim2.new(1, -R.MARGE_BORD, 1, -bas)
	end
	placer()

	local connexions: { RBXScriptConnection } = {}
	local okSignal, signal = pcall(function()
		return UserInputService:GetPropertyChangedSignal("PreferredInput" :: any)
	end)
	if okSignal and signal then
		table.insert(connexions, signal:Connect(placer))
	end

	ecran.Parent = parent

	-- Lueur du stade maximum : une respiration lente (sinus), branchée seulement quand il le faut
	local pulsation: RBXScriptConnection? = nil
	local temps = 0
	local function lueurA(transparence: number)
		lueur.BackgroundTransparency = transparence
		contour.Transparency = math.clamp(transparence - 0.35, 0, 1)
	end
	local function arreterPulsation()
		if pulsation then
			pulsation:Disconnect()
			pulsation = nil
		end
	end
	local function demarrerLueur()
		contour.Color = R.COULEURS_CRANS[nombre]
		contour.Thickness = 2
		if GuiService.ReducedMotionEnabled then
			arreterPulsation()
			lueurA(R.LUEUR_TRANSPARENCE_FIXE)
			return
		end
		if pulsation then
			return
		end
		temps = 0
		pulsation = RunService.RenderStepped:Connect(function(dt: number)
			if GuiService.ReducedMotionEnabled then
				arreterPulsation()
				lueurA(R.LUEUR_TRANSPARENCE_FIXE)
				return
			end
			temps += dt
			local onde = 0.5 + 0.5 * math.cos(temps * 2 * math.pi * R.LUEUR_FREQUENCE) -- 1 au départ : bien visible
			lueurA(R.LUEUR_TRANSPARENCE_MAX + (R.LUEUR_TRANSPARENCE_MIN - R.LUEUR_TRANSPARENCE_MAX) * onde)
		end)
	end
	local function eteindreLueur()
		arreterPulsation()
		lueur.BackgroundTransparency = 1
		contour.Color = R.COULEUR_CRAN_ETEINT
		contour.Thickness = 1
		contour.Transparency = 0.5
	end

	local tweens: { Tween } = {}
	local infoTransition = TweenInfo.new(R.DUREE_TRANSITION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local stadeActuel = -1

	local function afficher(stade: number)
		local s = math.clamp(math.floor(if stade == stade then stade else 0), 0, nombre)
		if s == stadeActuel then
			return
		end
		stadeActuel = s
		for _, tw in tweens do
			tw:Cancel()
		end
		table.clear(tweens)
		local instantane = GuiService.ReducedMotionEnabled
		for i, cran in crans do
			local allume = i <= s
			local cible = {
				BackgroundColor3 = if allume then R.COULEURS_CRANS[i] else R.COULEUR_CRAN_ETEINT,
				BackgroundTransparency = if allume then 0 else R.TRANSPARENCE_CRAN_ETEINT,
			}
			if instantane then
				cran.BackgroundColor3 = cible.BackgroundColor3
				cran.BackgroundTransparency = cible.BackgroundTransparency
			else
				local tw = TweenService:Create(cran, infoTransition, cible)
				table.insert(tweens, tw)
				tw:Play()
			end
		end
		libelle.Text = R.LIBELLES[s + 1] or ""
		libelle.TextColor3 = R.COULEURS_TEXTE[s + 1] or R.COULEURS_TEXTE[1]
		if s >= nombre then
			demarrerLueur()
		else
			eteindreLueur()
		end
	end

	afficher(0)

	return {
		afficher = afficher,
		stade = function(): number
			return stadeActuel
		end,
		detruire = function()
			arreterPulsation()
			for _, tw in tweens do
				tw:Cancel()
			end
			for _, c in connexions do
				c:Disconnect()
			end
			table.clear(connexions)
			ecran:Destroy()
		end,
	}
end

return IndicateurBruit
