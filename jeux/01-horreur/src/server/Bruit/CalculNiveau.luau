--!strict
--[[
	Rôle    : règle pure du niveau de bruit d'un joueur, sans aucun service Roblox
	          (testable sans Play : on lui donne des mesures et une horloge, elle rend un stade).
	          - stadeBrut : le plus fort des bruits en cours (nettoyage > course > action > marche > rien) ;
	          - noterSol  : repère la fin d'un saut ou d'une chute assez longue (atterrissage bruyant) ;
	          - lisser    : le niveau affiché monte tout de suite et redescend d'un stade à la fois,
	                        après un court maintien (pas de saut 4 -> 0 à l'écran).
	          Les chiffres viennent de Shared/Bruit/ReglagesBruit (passés en paramètre).
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

-- Ce que le serveur a observé d'un joueur à un instant donné
export type Mesure = {
	vitesse: number,      -- vitesse à plat de la racine (studs/s)
	auSol: boolean,       -- false en l'air (saut, chute)
	nettoie: boolean,     -- un outil en main est en train de nettoyer (attribut posé par le serveur)
	actionJusqua: number, -- instant jusqu'auquel une action bruyante dure encore (ramassage, atterrissage)
}

-- État de lissage et de saut d'un joueur (un par personnage)
export type Etat = {
	niveau: number,            -- niveau publié (lissé)
	prochaineBaisse: number,   -- instant où il pourra perdre un stade
	enLairDepuis: number?,     -- instant où il a quitté le sol (nil s'il est au sol)
}

local CalculNiveau = {}

function CalculNiveau.nouvelEtat(): Etat
	return { niveau = 0, prochaineBaisse = -math.huge, enLairDepuis = nil }
end

-- Stade du bruit fait en ce moment (0..STADE_MAX), sans lissage
function CalculNiveau.stadeBrut(m: Mesure, R: any, maintenant: number): number
	if m.nettoie then
		return R.STADE_NETTOYAGE
	end
	local stade = 0
	-- en l'air, les pieds ne font pas de bruit : c'est l'atterrissage qui en fait (actionJusqua)
	if m.auSol then
		if m.vitesse > R.SEUIL_VITESSE_COURSE then
			stade = R.STADE_COURSE
		elseif m.vitesse > R.VITESSE_MIN_MARCHE then
			stade = R.STADE_MARCHE
		end
	end
	if maintenant < m.actionJusqua then
		stade = math.max(stade, R.STADE_ACTION)
	end
	return stade
end

-- Suit les sauts. Renvoie true au moment où le joueur retombe après DUREE_AIR_MIN en l'air.
function CalculNiveau.noterSol(etat: Etat, auSol: boolean, maintenant: number, R: any): boolean
	if not auSol then
		if etat.enLairDepuis == nil then
			etat.enLairDepuis = maintenant
		end
		return false
	end
	local depuis = etat.enLairDepuis
	etat.enLairDepuis = nil
	return depuis ~= nil and maintenant - depuis >= R.DUREE_AIR_MIN
end

-- Niveau lissé : monte tout de suite, garde MAINTIEN secondes, puis perd un stade toutes les PAS_RETOMBEE
function CalculNiveau.lisser(etat: Etat, brut: number, maintenant: number, R: any): number
	if brut >= etat.niveau then
		etat.niveau = brut
		etat.prochaineBaisse = maintenant + R.MAINTIEN
	elseif maintenant >= etat.prochaineBaisse then
		etat.niveau = math.max(brut, etat.niveau - 1)
		etat.prochaineBaisse = maintenant + R.PAS_RETOMBEE
	end
	return etat.niveau
end

return CalculNiveau
