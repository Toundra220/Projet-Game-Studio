--[[
	Rôle    : retours visuels chez le joueur, liés au monstre (skill game-feel) :
	          - il te repère (état alerte, tu es sa cible) : petite secousse de caméra
	          - il te poursuit : l'image se désature et rougit d'autant plus qu'il est proche
	          - il t'attrape (attribut Vies qui baisse) : éclair rouge, forte secousse et message
	            avec les vies restantes
	          Rien d'autre que de l'affichage local : le serveur a déjà tout décidé
	          (MonstreIA : CibleId et Etat sur le monstre ; Vies.server : Vies sur le joueur).
	          Effets dans la caméra (ColorCorrectionEffect) : visibles par ce joueur seulement.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Réglages
local FORCE_SECOUSSE = 1          -- 0 = aucune secousse (confort), 1 = normal
local DECROISSANCE_SECOUSSE = 1.6 -- « trauma » perdu par seconde
local ANGLE_SECOUSSE_MAX = math.rad(2.5)
local TRAUMA_REPERE = 0.35        -- quand il te repère
local TRAUMA_PRISE = 0.9          -- quand il t'attrape
local PORTEE_TENSION = 45         -- en poursuite, la tension monte en dessous de cette distance
local DUREE_MESSAGE = 2.5

local joueur = Players.LocalPlayer
local monstre = workspace:WaitForChild("MonstreRodin")
local racineMonstre = monstre:WaitForChild("HumanoidRootPart")

-- Effet de couleur, placé dans la caméra (local à ce joueur)
local effet = Instance.new("ColorCorrectionEffect")
effet.Name = "TensionMonstre"
local function placerEffet()
	if workspace.CurrentCamera then
		effet.Parent = workspace.CurrentCamera
	end
end
placerEffet()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(placerEffet)

-- Message au centre de l'écran
local ecran = Instance.new("ScreenGui")
ecran.Name = "RetourMonstre"
ecran.ResetOnSpawn = false
ecran.IgnoreGuiInset = true
local message = Instance.new("TextLabel")
message.AnchorPoint = Vector2.new(0.5, 0.5)
message.Position = UDim2.fromScale(0.5, 0.35)
message.Size = UDim2.fromScale(0.8, 0.08)
message.BackgroundTransparency = 1
message.Font = Enum.Font.Garamond
message.TextScaled = true
message.TextColor3 = Color3.fromRGB(230, 60, 60)
message.TextStrokeTransparency = 0.4
message.TextTransparency = 1
message.TextStrokeColor3 = Color3.new(0, 0, 0)
message.Text = ""
local limite = Instance.new("UITextSizeConstraint")
limite.MaxTextSize = 48
limite.Parent = message
message.Parent = ecran
ecran.Parent = joueur:WaitForChild("PlayerGui")

local trauma = 0
local eclair = 0     -- 1 juste après une prise, redescend à 0
local tension = 0    -- 0..1 pendant une poursuite
local tempsSecousse = 0
local tweenMessage = nil

local function ajouterTrauma(quantite)
	trauma = math.clamp(trauma + quantite, 0, 1) -- les chocs s'additionnent, sans dépasser 1
end

local function afficherMessage(texte)
	if tweenMessage then
		tweenMessage:Cancel()
	end
	message.Text = texte
	message.TextTransparency = 0
	message.TextStrokeTransparency = 0.4
	tweenMessage = TweenService:Create(message,
		TweenInfo.new(DUREE_MESSAGE, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 })
	tweenMessage:Play()
end

local function estMaCible()
	return monstre:GetAttribute("CibleId") == joueur.UserId
end

-- Il te repère
monstre:GetAttributeChangedSignal("Etat"):Connect(function()
	if monstre:GetAttribute("Etat") == "alerte" and estMaCible() then
		ajouterTrauma(TRAUMA_REPERE)
	end
end)
-- CibleId peut arriver juste après Etat : on vérifie aussi dans ce sens
monstre:GetAttributeChangedSignal("CibleId"):Connect(function()
	if monstre:GetAttribute("Etat") == "alerte" and estMaCible() then
		ajouterTrauma(TRAUMA_REPERE * 0.5)
	end
end)

-- Il t'attrape
local viesPrecedentes = joueur:GetAttribute("Vies")
joueur:GetAttributeChangedSignal("Vies"):Connect(function()
	local vies = joueur:GetAttribute("Vies")
	if type(vies) == "number" and type(viesPrecedentes) == "number" and vies < viesPrecedentes then
		ajouterTrauma(TRAUMA_PRISE)
		eclair = 1
		if vies <= 0 then
			afficherMessage("Plus de vies... tout recommence")
		elseif vies == 1 then
			afficherMessage("Il t'a attrapé ! Dernière vie")
		else
			afficherMessage(("Il t'a attrapé ! Vies : %d"):format(vies))
		end
	end
	viesPrecedentes = vies
end)

local BLANC = Color3.new(1, 1, 1)
local ROUGE = Color3.fromRGB(255, 90, 90)

-- Après la caméra par défaut : on ajoute la secousse à la position qu'elle vient de calculer
RunService:BindToRenderStep("RetourMonstre", Enum.RenderPriority.Camera.Value + 1, function(dt)
	-- tension : seulement si c'est moi qu'il poursuit
	local tensionVoulue = 0
	local etat = monstre:GetAttribute("Etat")
	local perso = joueur.Character
	local maRacine = perso and perso:FindFirstChild("HumanoidRootPart")
	if maRacine and (etat == "poursuite" or etat == "alerte") and estMaCible() then
		local distance = (maRacine.Position - racineMonstre.Position).Magnitude
		tensionVoulue = math.clamp(1 - distance / PORTEE_TENSION, 0.25, 1)
	end
	tension += (tensionVoulue - tension) * (1 - math.exp(-3 * dt))
	eclair = math.max(0, eclair - dt * 1.5)

	effet.TintColor = BLANC:Lerp(ROUGE, math.clamp(tension * 0.35 + eclair * 0.8, 0, 1))
	effet.Saturation = -0.45 * tension - 0.4 * eclair
	effet.Contrast = 0.1 * tension + 0.2 * eclair

	-- secousse : trauma², sinus mélangés (pas d'aléatoire qui grésille), décroît vers 0
	if trauma > 0 then
		trauma = math.max(0, trauma - DECROISSANCE_SECOUSSE * dt)
		tempsSecousse += dt * 30
		local force = trauma * trauma * FORCE_SECOUSSE * ANGLE_SECOUSSE_MAX
		local camera = workspace.CurrentCamera
		if camera and force > 0 then
			camera.CFrame *= CFrame.Angles(
				force * math.sin(tempsSecousse * 1.7),
				force * math.sin(tempsSecousse * 2.3),
				force * 0.6 * math.sin(tempsSecousse * 1.1)
			)
		end
	end
end)
