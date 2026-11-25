--!strict
--[[
	Rôle    : tous les chiffres du NIVEAU DE BRUIT du joueur au même endroit (règle 9 de Regles-de-prompt).
	          Partagé : le serveur (Server/Bruit) s'en sert pour CALCULER le niveau, le client
	          (Client/Bruit) seulement pour l'AFFICHER (libellés, couleurs, tailles).
	          Le client ne décide rien et n'envoie rien : le niveau est écrit par le serveur dans
	          l'attribut ATTRIBUT_NIVEAU du Player.

	          Stades (le plus fort des bruits en cours l'emporte) :
	            0  immobile                                   « Silencieux »
	            1  marche                                     « Discret »
	            2  ramasser un objet, atterrir d'un saut      « Audible »
	            3  course (sprint)                            « Bruyant »
	            4  nettoyage (balai ou aspirateur en usage)   « BRUYANT » (indicateur complet)
	          Le stade 2 regroupe les bruits ponctuels du corps : fiche Monstre du coffre
	          (« Bruit : courir, aspirateur, ramasser/poser »). Ils sont plus forts qu'un pas de
	          marche mais plus courts et moins portants qu'une course.

	          La distance à laquelle le monstre entend chaque stade et sa façon d'y réagir sont
	          dans Server/Monstre/Reglages (PORTEE_OUIE_STADE_n, ECOUTE_*_STADE_n, VITESSE_ENQUETE_STADE_n).
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

return table.freeze({
	-- Stades
	STADE_MAX = 4,                       -- nombre de crans de l'indicateur (hors 0)
	STADE_MARCHE = 1,
	STADE_ACTION = 2,                    -- ramassage, atterrissage
	STADE_COURSE = 3,
	STADE_NETTOYAGE = 4,

	-- Réseau : attribut nombre entier 0..STADE_MAX sur le Player, écrit par le serveur seulement
	ATTRIBUT_NIVEAU = "NiveauBruit",

	-- Détection (serveur), vitesses mesurées à plat en studs/s sur la racine du personnage
	VITESSE_MIN_MARCHE = 3,              -- en dessous : immobile (petits glissements, rotation sur place)
	SEUIL_VITESSE_COURSE = 22,           -- au dessus : course. Entre la marche (16) et le sprint (32) de Shared/Sprint/ReglagesSprint
	DUREE_RAMASSAGE = 1.0,               -- secondes de stade 2 après avoir ramassé un objet
	DUREE_AIR_MIN = 0.45,                -- un saut ou une chute d'au moins 0,45 s fait du bruit en retombant...
	DUREE_ATTERRISSAGE = 0.6,            -- ... pendant 0,6 s (stade 2)

	-- Lissage (serveur) : le niveau monte tout de suite, redescend doucement
	MAINTIEN = 0.5,                      -- secondes à garder le niveau atteint avant de redescendre
	PAS_RETOMBEE = 0.3,                  -- puis il perd un stade toutes les 0,3 s (4 -> 0 : 0,5 + 4 x 0,3 = 1,7 s)

	-- Rythme (serveur)
	PERIODE_ANALYSE = 0.1,               -- secondes entre deux calculs du niveau de chaque joueur
	PERIODE_EMISSION = 0.5,              -- un joueur qui fait du bruit (stades 1 à 3) prévient le monstre au plus toutes les 0,5 s
	                                     -- (le nettoyage, stade 4, est déjà signalé par l'outil lui-même : Outils/Utilisations/Nettoyage)

	-- Indicateur (client seulement)
	LIBELLES = table.freeze({            -- index = stade + 1
		"Silencieux",
		"Discret",
		"Audible",
		"Bruyant",
		"BRUYANT",
	}),
	-- couleur de chaque cran allumé : du rouge sombre au rouge vif (DA sombre du manoir)
	COULEURS_CRANS = table.freeze({
		Color3.fromRGB(190, 40, 34),
		Color3.fromRGB(212, 46, 36),
		Color3.fromRGB(234, 54, 40),
		Color3.fromRGB(255, 70, 50),
	}),
	COULEUR_CRAN_ETEINT = Color3.fromRGB(70, 62, 58),
	TRANSPARENCE_CRAN_ETEINT = 0.35,
	-- couleur du libellé par stade (index = stade + 1) : clair pour rester lisible sur le fond sombre,
	-- puis rouge vif quand c'est complet
	COULEURS_TEXTE = table.freeze({
		Color3.fromRGB(190, 180, 170),
		Color3.fromRGB(236, 200, 190),
		Color3.fromRGB(242, 178, 165),
		Color3.fromRGB(250, 150, 132),
		Color3.fromRGB(255, 92, 70),
	}),
	COULEUR_FOND = Color3.fromRGB(20, 14, 10), -- même brun très sombre que Client/Outils/Notification
	TRANSPARENCE_FOND = 0.45,

	CRAN_LARGEUR = 8,                    -- pixels
	CRAN_HAUTEUR_MIN = 12,               -- hauteur du premier cran...
	CRAN_HAUTEUR_MAX = 32,               -- ... et du dernier (barres montantes, comme un signal)
	CRAN_ECART = 5,
	TAILLE_TEXTE = 16,
	MARGE_BORD = 16,                     -- pixels depuis le bord droit (dans la zone sûre)
	DECALAGE_BAS = 24,                   -- pixels depuis le bas sur ordinateur et manette
	DECALAGE_BAS_TACTILE = 156,          -- sur mobile : au dessus du bouton Courir (posé vers UDim2.new(1,-170,1,-140))
	DUREE_TRANSITION = 0.12,             -- secondes du fondu de couleur entre deux stades

	-- Lueur au stade maximum (douce, jamais un clignotement : moins d'un battement par seconde)
	LUEUR_FREQUENCE = 0.9,               -- battements par seconde
	LUEUR_TRANSPARENCE_MIN = 0.45,
	LUEUR_TRANSPARENCE_MAX = 0.8,
	LUEUR_TRANSPARENCE_FIXE = 0.6,       -- si le joueur a demandé moins de mouvement (ReducedMotionEnabled)
})
