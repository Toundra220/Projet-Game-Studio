--!strict
--[[
	Rôle    : léger retour visuel en course : le champ de vision de la caméra s'élargit de
	          FOV_BONUS degrés (interpolé), puis revient. Local à ce joueur, rien n'est envoyé.
	          Désactivable : FOV_ACTIF = false dans ReglagesSprint, ou réglage « réduire les
	          mouvements » de Roblox (GuiService.ReducedMotionEnabled).
	          On applique la DIFFÉRENCE d'un image à l'autre, pas une valeur absolue : un autre
	          script qui règle lui aussi le champ de vision (zoom, cinématique) n'est pas écrasé.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local GuiService = game:GetService("GuiService")

export type EffetCourse = {
	mettreAJour: (dt: number, court: boolean) -> (),
	retirer: () -> (),
}

local EffetCourse = {}

function EffetCourse.nouveau(reglages: any): EffetCourse
	local decalage = 0 -- degrés actuellement ajoutés à la caméra

	local function appliquer(nouveau: number)
		local camera = workspace.CurrentCamera
		if camera and nouveau ~= decalage then
			camera.FieldOfView += nouveau - decalage
		end
		decalage = nouveau
	end

	local function mettreAJour(dt: number, court: boolean)
		local actif = reglages.FOV_ACTIF and not GuiService.ReducedMotionEnabled
		local cible = if actif and court then reglages.FOV_BONUS else 0
		local suivant = decalage + (cible - decalage) * (1 - math.exp(-reglages.FOV_VITESSE * dt))
		if math.abs(cible - suivant) < 0.01 then
			suivant = cible
		end
		appliquer(suivant)
	end

	return { mettreAJour = mettreAJour, retirer = function() appliquer(0) end }
end

return EffetCourse
