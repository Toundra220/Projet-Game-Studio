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
	Date    : 2026-11-24 (corps entier + versions mur : 2026-11-25 ; poses refaites pour la prise
	          « poils côté +Z de la main », balai à l'envers corrigé : 2026-11-25)
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

-- IMPORTANT (mesuré dans Studio le 2026-11-25, rig R15) : la prise des outils (Tool.Grip,
-- DefinitionsOutils) met le manche dans le poing, l'extrémité utile (poils, tête d'aspirateur)
-- du côté +Z de la main. L'angle total « épaule + coude + taille » (dP + dC + tP) décide donc
-- où pointent les poils :
--   ~90°  : poils vers le bas (pose de repos « outil en main » de Roblox : 79 + 13) ;
--   ~110° : poils vers le bas et l'avant, au sol (versions sol) ;
--   ~180° : poils vers l'avant, à l'horizontale (versions mur) ;
--   ~0-30° (bras pendant) : poils vers l'ARRIÈRE, à l'horizontale. C'était le bug « balai à
--   l'envers » de la première version (dP 14-32, dC 4-14).
-- La main droite tient le haut du manche devant la poitrine (coude plié), la main gauche plus
-- bas sur le manche (bras tendu en travers, yaw négatif). Les angles du bras gauche ont été
-- cherchés dans Studio pour que la main gauche reste à moins de 0,25 stud du manche.
-- La taille tourne vers la droite (tY < 0) pour ramener les poils devant le joueur ;
-- le cou tourne en sens inverse pour garder les yeux sur la tache.

-- Balai au sol : vrai coup de balai à deux mains. Le buste penché suit le mouvement ;
-- les poils frottent le sol pendant l'aller (gauche -> droite) et se soulèvent au retour.
local Balayage: Forme = {
	duree = 1.0,
	cles = {
		cle(0.00, { dP = 25, dY = 52, dC = 100, gP = 63, gY = -48, gC = 0, tP = -15, tY = -10, cP = -24, cY = 6 }),
		cle(0.25, { dP = 22, dY = 52, dC = 100, gP = 60, gY = -50, gC = 0, tP = -18, tY = -25, cP = -28, cY = 15 }),
		cle(0.50, { dP = 25, dY = 52, dC = 100, gP = 63, gY = -48, gC = 0, tP = -15, tY = -40, cP = -24, cY = 24 }),
		-- retour : bras un peu levé, les poils quittent le sol (~0,6 stud)
		cle(0.75, { dP = 32, dY = 52, dC = 100, gP = 70, gY = -45, gC = 0, tP = -12, tY = -25, cP = -20, cY = 15 }),
		cle(1.00, { dP = 25, dY = 52, dC = 100, gP = 63, gY = -48, gC = 0, tP = -15, tY = -10, cP = -24, cY = 6 }),
	},
}

-- Balai sur un mur : manche tenu à l'horizontale à hauteur d'épaule, poils contre le mur
-- (environ 4,3 studs de haut, 3,4 studs devant), on frotte le slime en petits cercles.
local BalayageMur: Forme = {
	duree = 0.8,
	cles = {
		cle(0.00, { dP = 55, dY = 44, dC = 125, gP = 110, gY = -58, gC = 0, tP = 2, tY = -36, cP = 10, cY = 22 }),
		cle(0.20, { dP = 63, dY = 50, dC = 125, gP = 117, gY = -60, gC = 0, tP = 4, tY = -30, cP = 14, cY = 18 }),
		cle(0.40, { dP = 55, dY = 56, dC = 125, gP = 112, gY = -35, gC = 0, tP = 2, tY = -24, cP = 10, cY = 14 }),
		cle(0.60, { dP = 47, dY = 50, dC = 125, gP = 104, gY = -52, gC = 0, tP = 0, tY = -30, cP = 6,  cY = 18 }),
		cle(0.80, { dP = 55, dY = 44, dC = 125, gP = 110, gY = -58, gC = 0, tP = 2, tY = -36, cP = 10, cY = 22 }),
	},
}

-- Aspirateur au sol : on pousse (buste très penché, bras plus tendus) puis on ramène.
-- La tête de l'aspirateur reste au sol (0,1 à 0,2 stud) et avance d'environ 0,5 stud.
local Aspiration: Forme = {
	duree = 0.9,
	cles = {
		cle(0.00, { dP = 22, dY = 52, dC = 100, gP = 60, gY = -50, gC = 0, tP = -12, tY = -25, cP = -18, cY = 15 }),
		cle(0.45, { dP = 46, dY = 48, dC = 90,  gP = 78, gY = -42, gC = 0, tP = -30, tY = -25, cP = -14, cY = 15 }),
		cle(0.90, { dP = 22, dY = 52, dC = 100, gP = 60, gY = -50, gC = 0, tP = -12, tY = -25, cP = -18, cY = 15 }),
	},
}

-- Aspirateur sur un mur : tête de l'aspirateur contre le slime, on monte (5,4 studs)
-- et on descend (3,5 studs) le long du mur.
local AspirationMur: Forme = {
	duree = 0.9,
	cles = {
		cle(0.00, { dP = 45, dY = 50, dC = 125, gP = 102, gY = -51, gC = 0, tP = 0, tY = -30, cP = 6,  cY = 18 }),
		cle(0.45, { dP = 70, dY = 50, dC = 125, gP = 122, gY = -65, gC = 0, tP = 4, tY = -30, cP = 16, cY = 18 }),
		cle(0.90, { dP = 45, dY = 50, dC = 125, gP = 102, gY = -51, gC = 0, tP = 0, tY = -30, cP = 6,  cY = 18 }),
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
