--!strict
--[[
	Rôle    : décrit les mouvements des outils (va-et-vient du balai, de l'aspirateur) sous forme
	          de clés d'animation : à chaque instant, la rotation de l'épaule et du coude droits.
	          AnimationOutils.client fabrique une KeyframeSequence à partir de ces données
	          (aucun ID d'animation Roblox : tout est calculé).
	          Clé = champ « animation » de DefinitionsOutils.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

-- Rotations en espace de l'articulation (rig R15). Conventions mesurées en test dans Studio :
--   épaule : Angles(pitch > 0, 0, 0) lève le bras vers l'AVANT (pitch < 0 l'envoie derrière) ;
--   Angles(0, yaw, 0) * Angles(pitch, 0, 0) fait pivoter le bras levé autour de l'axe vertical
--   du torse, donc un balayage de gauche à droite (course de la main ~1,5 stud à ±32°) ;
--   coude : Angles(plie > 0, 0, 0) plie l'avant-bras vers le haut.
-- Amplitudes à régler dans Studio selon le rendu voulu.

export type Cle = {
	temps: number,   -- secondes depuis le début du cycle
	epaule: CFrame,  -- Transform de RightUpperArm.RightShoulder
	coude: CFrame,   -- Transform de RightLowerArm.RightElbow
}

export type Forme = {
	duree: number,   -- durée d'un aller-retour complet (le dernier cran répète le premier)
	cles: { Cle },
}

local function cle(temps: number, pitchDeg: number, yawDeg: number, coudeDeg: number): Cle
	return {
		temps = temps,
		epaule = CFrame.Angles(0, math.rad(yawDeg), 0) * CFrame.Angles(math.rad(pitchDeg), 0, 0),
		coude = CFrame.Angles(math.rad(coudeDeg), 0, 0),
	}
end

-- Balai : bras levé devant, il balaie de gauche à droite puis revient (0,7 s l'aller-retour).
local Balayage: Forme = {
	duree = 0.7,
	cles = {
		cle(0.00, 55, -32, 25),
		cle(0.35, 55, 32, 25),
		cle(0.70, 55, -32, 25),
	},
}

-- Aspirateur : bras qui pousse (coude tendu) puis tire (coude plié) devant le joueur
-- (0,8 s l'aller-retour).
local Aspiration: Forme = {
	duree = 0.8,
	cles = {
		cle(0.00, 40, 0, 60),
		cle(0.40, 70, 0, 10),
		cle(0.80, 40, 0, 60),
	},
}

-- Table gelée : une nouvelle forme = une nouvelle entrée ici, rien d'autre à changer.
local Formes: { [string]: Forme } = table.freeze({
	Balayage = Balayage,
	Aspiration = Aspiration,
})

return Formes
