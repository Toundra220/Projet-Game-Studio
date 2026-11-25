--!strict
--[[
	Rôle    : petite barre d'endurance, centrée en bas de l'écran. Blanche, un peu transparente,
	          avec un rail encore plus transparent. Seulement des Frames et un UICorner (pas d'image).
	          - visible dès qu'elle n'est pas pleine ou qu'on court ; s'estompe quand elle est pleine
	            et inutilisée (JAUGE_DELAI_ESTOMPE) ;
	          - jauge vidée : la barre devient grise et clignote doucement un instant ; un petit repère
	            montre le seuil de reprise (SEUIL_REPRISE). Pas de clignotement si le joueur a demandé
	            moins de mouvement (GuiService.ReducedMotionEnabled) : la couleur grise suffit ;
	          - placée dans les zones sûres (ScreenInsets) et au dessus de la barre d'objets, sous les
	            messages de Notification (qui finissent à 85 % de la hauteur).
	          ScreenGui avec ResetOnSpawn = false : elle survit au respawn. Elle ne fait qu'afficher :
	          les valeurs viennent des attributs du Player, écrits par le serveur.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local BLANC = Color3.new(1, 1, 1)
local GRIS = Color3.fromRGB(150, 150, 150)
local VITESSE_LISSAGE = 14        -- remplissage visuel : suit la valeur du serveur sans saccade
local VITESSE_FONDU = 6
local FREQUENCE_CLIGNOTEMENT = 3  -- battements par seconde
local TRANSPARENCE_CACHEE = 1

export type Jauge = {
	mettreAJour: (dt: number, endurance: number, epuise: boolean, court: boolean) -> (),
	signaler: (duree: number) -> (),  -- fait clignoter la barre un instant (jauge vide)
	detruire: () -> (),
}

local JaugeEndurance = {}

function JaugeEndurance.nouveau(reglages: any): Jauge
	local ecran = Instance.new("ScreenGui")
	ecran.Name = "JaugeEndurance"
	ecran.ResetOnSpawn = false
	ecran.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	ecran.DisplayOrder = 5 -- sous Notification (10)

	-- CanvasGroup : le fondu et le clignotement s'appliquent à toute la barre d'un coup
	local groupe = Instance.new("CanvasGroup")
	groupe.Name = "Jauge"
	groupe.AnchorPoint = Vector2.new(0.5, 1)
	groupe.Position = UDim2.new(0.5, 0, 1, -reglages.JAUGE_DECALAGE_BAS)
	groupe.Size = UDim2.new(reglages.JAUGE_LARGEUR, 0, 0, reglages.JAUGE_HAUTEUR)
	groupe.BackgroundColor3 = BLANC
	groupe.BackgroundTransparency = reglages.JAUGE_TRANSPARENCE_FOND
	groupe.BorderSizePixel = 0
	groupe.GroupTransparency = TRANSPARENCE_CACHEE
	groupe.Parent = ecran

	local contrainte = Instance.new("UISizeConstraint")
	contrainte.MinSize = Vector2.new(reglages.JAUGE_LARGEUR_MIN, reglages.JAUGE_HAUTEUR)
	contrainte.MaxSize = Vector2.new(reglages.JAUGE_LARGEUR_MAX, reglages.JAUGE_HAUTEUR)
	contrainte.Parent = groupe

	local coins = Instance.new("UICorner")
	coins.CornerRadius = UDim.new(0.5, 0)
	coins.Parent = groupe

	local remplissage = Instance.new("Frame")
	remplissage.Name = "Remplissage"
	remplissage.Size = UDim2.fromScale(1, 1)
	remplissage.BackgroundColor3 = BLANC
	remplissage.BorderSizePixel = 0
	remplissage.Parent = groupe

	-- repère du seuil de reprise : visible seulement quand la jauge est vidée
	local repere = Instance.new("Frame")
	repere.Name = "SeuilReprise"
	repere.AnchorPoint = Vector2.new(0.5, 0)
	repere.Position = UDim2.fromScale(reglages.SEUIL_REPRISE, 0)
	repere.Size = UDim2.new(0, 2, 1, 0)
	repere.BackgroundColor3 = BLANC
	repere.BackgroundTransparency = 0.3
	repere.BorderSizePixel = 0
	repere.Visible = false
	repere.Parent = groupe

	local joueur = Players.LocalPlayer
	ecran.Parent = joueur:WaitForChild("PlayerGui")

	local affichee = 1          -- valeur lissée
	local transparence = TRANSPARENCE_CACHEE
	local inactif = 0           -- secondes pleine et sans courir
	local clignoteJusqua = 0
	local horloge = 0

	local function mettreAJour(dt: number, endurance: number, epuise: boolean, court: boolean)
		-- recrée l'interface si elle a été détruite (ex. ResetOnSpawn réglé ailleurs)
		if not ecran.Parent then
			ecran.Parent = joueur:WaitForChild("PlayerGui")
		end
		horloge += dt
		affichee += (endurance - affichee) * (1 - math.exp(-VITESSE_LISSAGE * dt))
		remplissage.Size = UDim2.fromScale(math.clamp(affichee, 0, 1), 1)
		remplissage.BackgroundColor3 = if epuise then GRIS else BLANC
		repere.Visible = epuise

		local pleine = endurance >= 0.999 and not epuise and not court
		inactif = if pleine then inactif + dt else 0
		local cible = if inactif > reglages.JAUGE_DELAI_ESTOMPE then TRANSPARENCE_CACHEE else reglages.JAUGE_TRANSPARENCE

		-- clignotement : de la barre vers le transparent, doucement (jamais plein écran)
		if horloge < clignoteJusqua and not GuiService.ReducedMotionEnabled then
			local battement = 0.5 + 0.5 * math.sin(horloge * FREQUENCE_CLIGNOTEMENT * 2 * math.pi)
			cible = math.max(cible, reglages.JAUGE_TRANSPARENCE) + (0.85 - reglages.JAUGE_TRANSPARENCE) * battement * 0.8
		end

		transparence += (cible - transparence) * (1 - math.exp(-VITESSE_FONDU * dt))
		groupe.GroupTransparency = math.clamp(transparence, 0, 1)
	end

	local function signaler(duree: number)
		clignoteJusqua = horloge + duree
		inactif = 0
	end

	local function detruire()
		ecran:Destroy()
	end

	return { mettreAJour = mettreAJour, signaler = signaler, detruire = detruire }
end

return JaugeEndurance
