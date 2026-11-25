--!strict
--[[
	Rôle    : tous les chiffres du sprint et de l'endurance au même endroit (règle 9 de
	          Regles-de-prompt). Partagé : le serveur s'en sert pour décider, le client pour
	          afficher (jauge, champ de vision) et pour reconnaître les noms des attributs.

	          ÉQUILIBRAGE (voir le rapport de la session du 2026-11-25) : le monstre court à 24
	          (Monstre/Reglages : VITESSE_POURSUITE), le joueur marche à 16. Le sprint est fait
	          pour qu'une jauge PLEINE permette d'échapper au monstre et qu'une jauge entamée
	          ne le permette pas : c'est le piège voulu. Si on change VITESSE_COURSE ou
	          DUREE_JAUGE, refaire le calcul et le test en Play (le monstre voit à 65 studs
	          pendant la poursuite : il faut creuser l'écart au delà, puis tenir encore
	          quelques secondes pour qu'il abandonne sa poursuite aveugle).
	          Le bruit : Monstre/Reglages.SEUIL_VITESSE_BRUIT doit rester entre la marche
	          (VITESSE_MARCHE) et la course (VITESSE_COURSE), sinon la marche devient bruyante.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

return table.freeze({
	-- Vitesses (studs par seconde)
	VITESSE_MARCHE = 16,          -- la même que StarterPlayer.CharacterWalkSpeed
	VITESSE_COURSE = 32,          -- plus que le monstre en poursuite (24)

	-- Endurance (jauge de 0 à 1, tenue par le serveur)
	DUREE_JAUGE = 7,              -- secondes de course avec la jauge pleine
	DELAI_RECHARGE = 1.5,         -- secondes sans courir avant que la jauge recommence à se remplir
	DUREE_RECHARGE = 12,          -- secondes pour remplir la jauge de 0 à 1
	SEUIL_REPRISE = 0.3,          -- jauge vidée : on ne peut courir de nouveau qu'à partir de 30 %
	VITESSE_MIN_MOUVEMENT = 2,    -- en dessous (studs/s à plat), le joueur est à l'arrêt : pas de course, pas de dépense
	PERIODE_PUBLICATION = 0.1,    -- secondes minimum entre deux envois de l'endurance aux clients

	-- Réseau
	NOM_DOSSIER_REMOTES = "RemotesSprint",
	NOM_REMOTE_COURSE = "DemanderCourse",   -- client -> serveur : (veutCourir: boolean)
	ATTRIBUT_ENDURANCE = "Endurance",       -- sur le Player : nombre 0..1 (écrit par le serveur seulement)
	ATTRIBUT_EPUISE = "Epuise",             -- sur le Player : vrai tant que la jauge n'a pas atteint SEUIL_REPRISE
	ATTRIBUT_COURT = "Court",               -- sur le Player : vrai quand le serveur le fait courir
	LIMITE_CAPACITE = 8,                    -- rafale permise de demandes de course par joueur...
	LIMITE_RECHARGE = 4,                    -- ... et demandes rendues par seconde

	-- Touches (noms d'actions pour ContextActionService)
	NOM_ACTION = "Courir",
	TOUCHES = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3 },
	TEXTE_BOUTON_TACTILE = "Courir",
	TACTILE_BASCULE = true,       -- mobile : un appui lance la course, un autre l'arrête (le pouce reste libre pour la caméra)

	-- Retour joueur (client seulement)
	FOV_ACTIF = true,             -- false : aucun changement de champ de vision
	FOV_BONUS = 5,                -- degrés ajoutés pendant la course
	FOV_VITESSE = 7,              -- rapidité de l'interpolation (plus grand = plus vif)

	-- Jauge (client seulement)
	JAUGE_LARGEUR = 0.2,          -- part de la largeur de l'écran...
	JAUGE_LARGEUR_MIN = 120,      -- ... entre 120 et 260 pixels
	JAUGE_LARGEUR_MAX = 260,
	JAUGE_HAUTEUR = 8,            -- pixels
	JAUGE_DECALAGE_BAS = 88,      -- pixels au dessus du bas de l'écran : au dessus de la barre d'objets (Backpack)
	JAUGE_DELAI_ESTOMPE = 1.5,    -- jauge pleine et inutilisée : elle s'estompe après 1,5 s
	JAUGE_TRANSPARENCE = 0.15,    -- transparence du groupe quand la jauge est visible (« un peu transparente »)
	JAUGE_TRANSPARENCE_FOND = 0.8,-- le fond (rail) est encore plus transparent
})
