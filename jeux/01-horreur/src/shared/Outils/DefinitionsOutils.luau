--!strict
--[[
	Rôle    : données gelées des outils (balai, aspirateur) et réglages communs
	          (noms de tags et d'attributs, portées). Ajouter un outil = ajouter
	          une entrée dans Definitions. Partagé entre client et serveur.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Types = require(script.Parent:WaitForChild("Types"))

local Reglages = {
	-- Tags
	TAG_RAMASSABLE = "Ramassable",
	TAG_NETTOYABLE = "Nettoyable",

	-- Attributs
	ATTRIBUT_OUTIL = "Outil",
	ATTRIBUT_PERMANENT = "Permanent",
	ATTRIBUT_EN_UTILISATION = "EnUtilisation",
	ATTRIBUT_PROGRESSION = "Progression",
	ATTRIBUT_NETTOYE = "Nettoye",
	ATTRIBUT_OUTIL_REQUIS = "OutilRequis",
	ATTRIBUT_DUREE = "DureeNettoyage",

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
		porteeUtilisation = 7,
		-- le modèle a les poils vers +Y : demi-tour pour les poils en bas, main plus haut sur le manche
		prise = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.pi, 0, 0),
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
		porteeUtilisation = 7,
		bruit = table.freeze({ portee = 45, periode = 1 }),
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
