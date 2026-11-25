--!strict
--[[
	Rôle    : tous les chiffres des gouttes de slime qui coulent des taches murales
	          (animation purement visuelle, côté client : Client/Taches/GouttesSlime).
	          Changer un chiffre ici suffit. Les durées sont en secondes, les distances en studs.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]

return table.freeze({
	-- Quelles taches et d'où partent les gouttes
	TYPE_TACHE = "Mur",           -- valeur de l'attribut TypeTache concernée
	PREFIXE_SOURCE = "Bout",      -- les parties « Bout1, Bout2... » sont les bas des coulures
	DECALAGE_NORMALE = 0.2,       -- la goutte est avancée devant le mur (évite qu'elle entre dedans)
	SOURCES_MAX_PAR_TACHE = 12,   -- sécurité

	-- Distance : au-delà, la tache n'est plus animée (rien n'est créé)
	DISTANCE_MAX = 60,

	-- Rythme : une nouvelle goutte par tache toutes les INTERVALLE secondes (aléatoire), lent et poisseux
	INTERVALLE_MIN = 1.5,
	INTERVALLE_MAX = 5,
	GOUTTES_SIMULTANEES_PAR_TACHE = 2,
	-- Moins de gouttes quand on nettoie : l'intervalle est divisé par (1 - Progression * REDUCTION_PROGRESSION)
	-- (0 = pas d'effet ; 0,85 = presque plus rien à 100 %)
	REDUCTION_PROGRESSION = 0.85,

	-- Pool de parties locales : jamais plus de PARTIES_MAX parties en même temps
	PARTIES_MAX = 20,
	GOUTTES_MAX_TOTAL = 8,        -- gouttes (formation ou chute) en même temps, toutes taches confondues

	-- Apparence (le vert du slime existant : 88, 214, 54)
	COULEUR = Color3.fromRGB(88, 214, 54),
	MATIERE = Enum.Material.SmoothPlastic,
	REFLECTANCE = 0.15,
	TRANSPARENCE_GOUTTE = 0.05,

	-- Formation : la goutte grossit au bas de la coulure puis s'allonge avant de se détacher
	DIAMETRE_MIN = 0.28,
	DIAMETRE_MAX = 0.5,
	FORMATION_DUREE_MIN = 1.6,
	FORMATION_DUREE_MAX = 3.2,
	ALLONGEMENT_FORMATION = 0.9,  -- +90 % de hauteur juste avant de tomber (le fil s'étire)
	PART_ALLONGEMENT = 0.45,      -- dernière part de la formation consacrée à l'allongement (0 à 1)

	-- Chute
	GRAVITE = 28,                 -- studs/s² (workspace.Gravity vaut 196 : volontairement lent et poisseux)
	ETIREMENT_VITESSE = 0.012,    -- la goutte s'étire de 1,2 % par stud/s de vitesse
	ETIREMENT_MAX = 0.7,
	HAUTEUR_CHUTE_MIN = 0.8,      -- une coulure trop près du sol ne fait pas de goutte
	PORTEE_RAYON_SOL = 40,

	-- Flaque au sol
	FLAQUE_EPAISSEUR = 0.06,
	FLAQUE_RAYON_FACTEUR_MIN = 1.6, -- rayon final = diamètre de la goutte x ce facteur
	FLAQUE_RAYON_FACTEUR_MAX = 2.4,
	FLAQUE_ETALEMENT_DUREE = 0.25,
	FLAQUE_DUREE_MIN = 1.5,       -- durée avant la disparition (fondu)
	FLAQUE_DUREE_MAX = 3,
	FLAQUE_TRANSPARENCE_DEBUT = 0.1,
	FLAQUE_DECALAGE_SOL = 0.03,

	-- Petites éclaboussures
	ECLATS_MIN = 2,
	ECLATS_MAX = 3,
	ECLAT_DIAMETRE_FACTEUR = 0.35, -- par rapport à la goutte
	ECLAT_VITESSE_LATERALE_MIN = 2,
	ECLAT_VITESSE_LATERALE_MAX = 4.5,
	ECLAT_VITESSE_HAUTE_MIN = 4,
	ECLAT_VITESSE_HAUTE_MAX = 7,
	ECLAT_GRAVITE = 40,
})
