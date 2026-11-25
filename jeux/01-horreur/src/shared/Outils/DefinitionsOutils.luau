--!strict
--[[
	Rôle    : données gelées des outils (balai, aspirateur) et réglages communs
	          (noms de tags et d'attributs, portées). Ajouter un outil = ajouter
	          une entrée dans Definitions. Partagé entre client et serveur.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24 (modifié : 2026-11-25, bruit du balai, vitesseNettoyage, FacteurBruit, OUTIL_DE_DEPART,
	          prises du balai et de l'aspirateur)
]]

local Types = require(script.Parent:WaitForChild("Types"))

local Reglages = {
	-- Tags
	TAG_RAMASSABLE = "Ramassable",
	TAG_NETTOYABLE = "Nettoyable",

	-- Outil à prendre en premier : le client le montre à travers les murs tant qu'on ne l'a pas (RepereBalai)
	OUTIL_DE_DEPART = "Balai",

	-- Attributs
	ATTRIBUT_OUTIL = "Outil",
	ATTRIBUT_PERMANENT = "Permanent",
	ATTRIBUT_EN_UTILISATION = "EnUtilisation",
	ATTRIBUT_PROGRESSION = "Progression",
	ATTRIBUT_NETTOYE = "Nettoye",
	ATTRIBUT_OUTIL_REQUIS = "OutilRequis",
	ATTRIBUT_DUREE = "DureeNettoyage",
	ATTRIBUT_FACTEUR_BRUIT = "FacteurBruit", -- posé par le serveur sur la tache : multiplie la portée du bruit de l'outil
	ATTRIBUT_TYPE_TACHE = "TypeTache",       -- sur la tache : « Sol » ou « Mur »
	ATTRIBUT_TYPE_CIBLE = "TypeCible",       -- posé par le serveur sur l'outil en utilisation : type de la cible (animation sol / mur)

	-- Distances et angles
	PORTEE_RAMASSAGE = 8,                -- studs
	TOLERANCE_PORTEE = 4,                -- marge de latence, utilisée côté serveur
	DEMI_ANGLE_CIBLAGE = math.rad(30),   -- cône de visée autour de la caméra

	-- Temps
	PERIODE_DETECTION = 0.1,             -- secondes entre deux détections côté client
}

local Definitions: { [string]: Types.DefinitionOutil } = {
	Balai = {
		id = "Balai",
		nomAffiche = "balai",
		article = "le balai",
		payant = false,
		idGamePass = 0,
		utilisation = "Nettoyage",
		animation = "Balayage",
		verbeUtilisation = "Balayer",
		tagCible = "Nettoyable",
		dureeUtilisation = 4,
		vitesseNettoyage = 1,   -- référence : les durées des taches (ReglagesTaches) sont données pour le balai
		porteeUtilisation = 7,
		-- tout nettoyage fait du bruit : le balai racle le sol, moins fort que l'aspirateur
		-- (et moins fort que des pas de course, 35 studs : voir Monstre/Reglages)
		bruit = table.freeze({ portee = 25, periode = 1.2 }),
		-- Le modèle a les poils vers +Y : le demi-tour met les poils côté +Z de la main (vers le bas
		-- dans la pose de repos, bras levé à 92°). La main tient le manche à 0,9 stud au-dessus du
		-- centre : au repos les poils frôlent le sol (0,1 stud, mesuré). Les poses de
		-- FormesAnimation sont calculées pour CETTE prise : ne pas changer l'une sans l'autre.
		prise = CFrame.new(0, -0.9, 0) * CFrame.Angles(math.pi, 0, 0),
	},
	Aspirateur = {
		id = "Aspirateur",
		nomAffiche = "aspirateur",
		article = "l'aspirateur",
		payant = true,
		idGamePass = 0, -- À REMPLIR par Romain : ID du game pass (Creator Hub)
		utilisation = "Nettoyage",
		animation = "Aspiration",
		verbeUtilisation = "Aspirer",
		tagCible = "Nettoyable",
		dureeUtilisation = 2.5,
		vitesseNettoyage = 1.6, -- 4 s / 2,5 s : même rapport qu'avant entre les deux outils
		porteeUtilisation = 7,
		bruit = table.freeze({ portee = 45, periode = 1 }),
		-- Le modèle a la tête (brosse, roues) vers -Y et la poignée vers +Y : sans rotation, la tête
		-- est côté +Z de la main, comme les poils du balai, donc les mêmes poses marchent.
		-- Main à 1 stud au-dessus du centre : au repos la tête frôle le sol (mesuré).
		prise = CFrame.new(0, 1, 0),
	},
}

-- Gel des définitions (et de leurs sous-tables) : personne ne les modifie en cours de partie
for _, definition in Definitions do
	table.freeze(definition)
end
table.freeze(Definitions)
table.freeze(Reglages)

-- Renvoie la définition d'un outil, ou nil si l'id n'est pas un texte connu.
-- (L'id peut venir du client : on ne lui fait pas confiance.)
local function obtenir(id: unknown): Types.DefinitionOutil?
	if type(id) ~= "string" then
		return nil
	end
	return Definitions[id]
end

return {
	Reglages = Reglages,
	Definitions = Definitions,
	obtenir = obtenir,
}
