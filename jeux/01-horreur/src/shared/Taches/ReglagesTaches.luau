--!strict
--[[
	Rôle    : tous les chiffres des taches de ménage (saletés du manoir) au même endroit.
	          Une tache du dossier Workspace.Taches porte seulement l'attribut « TypeTache »
	          (« Sol » ou « Mur ») ; le serveur (Taches/Taches.server) lui applique au démarrage
	          les valeurs ci-dessous (DureeNettoyage, FacteurBruit, tag Nettoyable) : changer un
	          chiffre ici suffit, sans toucher aux objets de Studio.
	          Les durées sont données pour le balai (vitesse 1) ; l'aspirateur les divise par sa
	          vitesseNettoyage (voir Outils/DefinitionsOutils). Ajouter un type de tache = ajouter
	          une entrée dans TYPES. Partagé entre le serveur et le client.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]

export type TypeTache = {
	duree: number,        -- secondes de nettoyage au balai
	facteurBruit: number, -- multiplie la portée du bruit de l'outil
}

local TYPES: { [string]: TypeTache } = {
	-- éclaboussure sombre au sol : on balaie, c'est court
	Sol = table.freeze({ duree = 6, facteurBruit = 1 }),
	-- slime vert qui coule sur un mur : il faut frotter, c'est la tache la plus longue et la plus bruyante
	Mur = table.freeze({ duree = 11, facteurBruit = 1.3 }),
}

local ATTRIBUT_MULTIPLICATEUR = "MultiplicateurDuree" -- facultatif sur une tache : 0,7 = 30 % plus courte, 1,5 = 50 % plus longue
local MULTIPLICATEUR_MIN = 0.25
local MULTIPLICATEUR_MAX = 4

-- Définition d'un type de tache, ou nil si le nom n'est pas un texte connu
local function obtenirType(nom: unknown): TypeTache?
	if type(nom) ~= "string" then
		return nil
	end
	return TYPES[nom]
end

-- Multiplicateur de durée d'une tache : 1 par défaut ; une valeur fausse (pas un nombre, NaN) vaut 1,
-- une valeur hors limites est ramenée dans [MULTIPLICATEUR_MIN, MULTIPLICATEUR_MAX]
local function multiplicateurDe(objet: Instance): number
	local valeur = objet:GetAttribute(ATTRIBUT_MULTIPLICATEUR)
	if type(valeur) ~= "number" or valeur ~= valeur then
		return 1
	end
	return math.clamp(valeur, MULTIPLICATEUR_MIN, MULTIPLICATEUR_MAX)
end

return table.freeze({
	-- Où et comment reconnaître les taches
	NOM_DOSSIER = "Taches",                -- Workspace.Taches (sous-dossiers par étage et par pièce)
	ATTRIBUT_TYPE = "TypeTache",           -- sur chaque tache : une clé de TYPES
	ATTRIBUT_MULTIPLICATEUR = ATTRIBUT_MULTIPLICATEUR,

	-- Compteurs écrits par le serveur sur le dossier Workspace.Taches (lecture : tests, futur TaskManager)
	ATTRIBUT_TOTAL = "Total",
	ATTRIBUT_RESTANTES = "Restantes",

	-- Avertissement du joueur : MonstreIA pose cet attribut booléen sur le Player tant que le monstre
	-- vient voir le bruit que CE joueur fait en nettoyant ; le client (Taches/AvertissementBruit) l'affiche.
	ATTRIBUT_AVERTISSEMENT = "MonstreAttire",
	MESSAGE_AVERTISSEMENT = "Ton bruit a été entendu : il approche !",
	DUREE_MESSAGE = 4, -- secondes d'affichage du message

	TYPES = table.freeze(TYPES),
	obtenirType = obtenirType,
	multiplicateurDe = multiplicateurDe,
})
