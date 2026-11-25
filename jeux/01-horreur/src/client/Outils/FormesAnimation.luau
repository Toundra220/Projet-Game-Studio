--!strict
--[[
	Rôle    : décrit les mouvements des outils sous forme de clés d'animation pour tout le haut
	          du corps : épaules et coudes droit ET gauche (les deux mains sur le manche), taille
	          (pencher, tourner le buste) et cou (regarder la tache).
	          Une version « sol » et une version « mur » par outil : AnimationOutils.client choisit
	          `<animation>Mur` quand la cible est une tache murale (attribut TypeCible de l'outil).
	          AnimationOutils.client fabrique une KeyframeSequence à partir de ces données
	          (aucun ID d'animation Roblox : tout est calculé).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24 (corps entier + versions mur : 2026-11-25)
]]

-- Rotations en espace de l'articulation (rig R15). Conventions :
--   épaule : Angles(pitch > 0, 0, 0) lève le bras vers l'AVANT (mesuré en test dans Studio) ;
--            Angles(0, yaw, 0) * Angles(pitch, 0, 0) fait pivoter le bras levé autour de l'axe
--            vertical du torse (balayage gauche-droite) ;
--   coude  : Angles(plie > 0, 0, 0) plie l'avant-bras vers le haut ;
--   taille : pitch < 0 penche le buste en avant, yaw tourne les épaules ;
--   cou    : pitch < 0 baisse la tête.
-- Toutes les valeurs sont en degrés. Amplitudes à régler dans Studio selon le rendu voulu.

export type Cle = {
	temps: number,      -- secondes depuis le début du cycle
	epauleD: CFrame,    -- Transform de RightUpperArm.RightShoulder
	coudeD: CFrame,     -- Transform de RightLowerArm.RightElbow
	epauleG: CFrame,    -- Transform de LeftUpperArm.LeftShoulder
	coudeG: CFrame,     -- Transform de LeftLowerArm.LeftElbow
	taille: CFrame,     -- Transform de UpperTorso.Waist
	cou: CFrame,        -- Transform de Head.Neck
}

export type Forme = {
	duree: number,      -- durée d'un cycle complet (la dernière clé répète la première)
	cles: { Cle },
}

type Valeurs = {
	dP: number, dY: number, dC: number,   -- bras droit : pitch, yaw, coude
	gP: number, gY: number, gC: number,   -- bras gauche
	tP: number, tY: number,               -- taille : pencher, tourner
	cP: number, cY: number,               -- cou : baisser, tourner
}

local function epaule(pitch: number, yaw: number): CFrame
	return CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)
end

local function cle(temps: number, v: Valeurs): Cle
	return {
		temps = temps,
		epauleD = epaule(v.dP, v.dY),
		coudeD = CFrame.Angles(math.rad(v.dC), 0, 0),
		epauleG = epaule(v.gP, v.gY),
		coudeG = CFrame.Angles(math.rad(v.gC), 0, 0),
		taille = CFrame.Angles(0, math.rad(v.tY), 0) * CFrame.Angles(math.rad(v.tP), 0, 0),
		cou = CFrame.Angles(0, math.rad(v.cY), 0) * CFrame.Angles(math.rad(v.cP), 0, 0),
	}
end

-- Balai au sol : vrai coup de balai à deux mains. Le buste penché suit le mouvement ;
-- le balai appuie au sol pendant l'aller (bras plus bas, plus penché) et se soulève au retour.
local Balayage: Forme = {
	duree = 1.0,
	cles = {
		-- bras droit bas (les poils touchent le sol), main gauche plus haut sur le manche
		cle(0.00, { dP = 22, dY = -32, dC = 8,  gP = 48, gY = -10, gC = 80, tP = -14, tY = -18, cP = -24, cY = -8 }),
		cle(0.25, { dP = 14, dY = 0,   dC = 4,  gP = 42, gY = 15,  gC = 76, tP = -19, tY = 0,   cP = -28, cY = 0 }),
		cle(0.50, { dP = 22, dY = 32,  dC = 8,  gP = 48, gY = 40,  gC = 80, tP = -14, tY = 18,  cP = -24, cY = 8 }),
		cle(0.75, { dP = 32, dY = 0,   dC = 14, gP = 56, gY = 15,  gC = 86, tP = -10, tY = 0,   cP = -20, cY = 0 }),
		cle(1.00, { dP = 22, dY = -32, dC = 8,  gP = 48, gY = -10, gC = 80, tP = -14, tY = -18, cP = -24, cY = -8 }),
	},
}

-- Balai sur un mur : on frotte le slime en petits cercles à hauteur de poitrine,
-- l'autre main appuyée plus bas sur le manche, la tête levée vers la tache.
local BalayageMur: Forme = {
	duree = 0.8,
	cles = {
		cle(0.00, { dP = 105, dY = -14, dC = 30, gP = 80, gY = 18, gC = 45, tP = 2, tY = -6, cP = 10, cY = -4 }),
		cle(0.20, { dP = 122, dY = 0,   dC = 14, gP = 92, gY = 22, gC = 32, tP = 4, tY = 0,  cP = 14, cY = 0 }),
		cle(0.40, { dP = 105, dY = 14,  dC = 30, gP = 80, gY = 26, gC = 45, tP = 2, tY = 6,  cP = 10, cY = 4 }),
		cle(0.60, { dP = 90,  dY = 0,   dC = 44, gP = 70, gY = 22, gC = 58, tP = 0, tY = 0,  cP = 6,  cY = 0 }),
		cle(0.80, { dP = 105, dY = -14, dC = 30, gP = 80, gY = 18, gC = 45, tP = 2, tY = -6, cP = 10, cY = -4 }),
	},
}

-- Aspirateur au sol : on pousse loin (bras tendus, buste penché) puis on ramène (coudes pliés).
local Aspiration: Forme = {
	duree = 0.9,
	cles = {
		cle(0.00, { dP = 38, dY = 0, dC = 62, gP = 30, gY = 20, gC = 72, tP = -6,  tY = -4, cP = -16, cY = 0 }),
		cle(0.45, { dP = 72, dY = 0, dC = 8,  gP = 62, gY = 14, gC = 24, tP = -18, tY = 4,  cP = -24, cY = 0 }),
		cle(0.90, { dP = 38, dY = 0, dC = 62, gP = 30, gY = 20, gC = 72, tP = -6,  tY = -4, cP = -16, cY = 0 }),
	},
}

-- Aspirateur sur un mur : on monte et descend le long du slime, bras levés.
local AspirationMur: Forme = {
	duree = 0.9,
	cles = {
		cle(0.00, { dP = 88,  dY = 0, dC = 50, gP = 80,  gY = 18, gC = 58, tP = 0, tY = -3, cP = 6,  cY = 0 }),
		cle(0.45, { dP = 124, dY = 0, dC = 14, gP = 112, gY = 14, gC = 26, tP = 4, tY = 3,  cP = 16, cY = 0 }),
		cle(0.90, { dP = 88,  dY = 0, dC = 50, gP = 80,  gY = 18, gC = 58, tP = 0, tY = -3, cP = 6,  cY = 0 }),
	},
}

-- Table gelée : une nouvelle forme = une nouvelle entrée ici, rien d'autre à changer.
-- Convention : la version murale d'une forme s'appelle `<nom>Mur`.
local Formes: { [string]: Forme } = table.freeze({
	Balayage = Balayage,
	BalayageMur = BalayageMur,
	Aspiration = Aspiration,
	AspirationMur = AspirationMur,
})

return Formes
