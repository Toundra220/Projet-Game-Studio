--[[
	Rôle    : tous les chiffres du monstre au même endroit (règle 9 de Regles-de-prompt).
	          Chaque valeur peut être remplacée SANS toucher au code : ajouter sur le modèle
	          Workspace.MonstreRodin un attribut du même nom et du même type
	          (ex. attribut nombre « DELAI_DEPART » = 0 pour tester, booléen « DEBUG » = true).
	          Lu une seule fois au démarrage du serveur.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24 (modifié : 2026-11-25, écoute des bruits de nettoyage, AGENT_HAUTEUR 16, apparition au balai ;
	          réaction par stade de bruit : le seuil de course est passé dans Shared/Bruit/ReglagesBruit)
]]

local DEFAUTS = {
	-- Départ
	DELAI_DEPART = 7,              -- secondes après son apparition dans la chambre (conception : 7 s)
	OUTIL_APPARITION = "Balai",    -- il n'apparaît que quand un joueur ramasse cet outil (id dans DefinitionsOutils)
	PROFONDEUR_CACHE = 250,        -- avant son apparition : rangé 250 studs sous sa chambre, ancré (reste sous FallenPartsDestroyHeight = -500)

	-- Vue
	PORTEE_VUE = 50,               -- distance max à laquelle il remarque un joueur droit devant (studs)
	PORTEE_VUE_POURSUITE = 65,     -- en poursuite il garde sa cible de vue un peu plus loin (évite le clignotement)
	DEMI_ANGLE_VUE_DEG = 65,       -- champ de vision : 2 x 65 = 130° devant lui
	PORTEE_BORD_VUE = 0.6,         -- au bord du champ de vision, il ne voit qu'à 60 % de la portée
	PORTEE_PROXIMITE = 10,         -- plus près, il sent le joueur même dans son dos (si pas de mur)
	TEMPS_REACTION_PRES = 0.15,    -- secondes pour repérer un joueur tout proche...
	TEMPS_REACTION_LOIN = 1.0,     -- ... et un joueur au bout de sa portée de vue
	OUBLI_VIGILANCE = 0.5,         -- vigilance perdue par seconde quand il ne voit plus le joueur
	SEUIL_SOUPCON = 0.3,           -- vigilance à partir de laquelle il s'arrête pour regarder (soupçon)
	TRANSPARENCE_TRAVERSEE = 0.95, -- une pièce au moins aussi transparente ne bloque pas la vue
	HAUTEUR_YEUX = 2.5,            -- si le modèle n'a pas de tête : yeux à 2,5 studs au dessus de la racine

	-- Ouïe : générale
	FACTEUR_ETAGE = 2,             -- la distance verticale compte double (le plancher étouffe le bruit)
	IMPRECISION_OUIE = 0.12,       -- de loin il situe mal le bruit : erreur jusqu'à 12 % de la distance...
	IMPRECISION_MAX = 6,           -- ... sans dépasser 6 studs
	PORTEE_BRUIT_MAX = 200,        -- portée max acceptée pour MonstreBruit
	ECART_NOUVEAU_BRUIT = 4,       -- un bruit à plus de 4 studs du précédent est un autre endroit : il change de but
	DISTANCE_SUR_PLACE = 12,       -- à moins de 12 studs d'un bruit qu'il fouille déjà, un bruit au même endroit ne le fait plus se remettre à écouter
	DUREE_VIE_BRUIT = 3,           -- un bruit entendu mais pas encore traité est oublié au bout de 3 s

	-- Ouïe : réaction par stade de bruit (stades de Shared/Bruit/ReglagesBruit, calculés par Server/Bruit).
	-- Plus le stade est haut : il l'entend de plus loin, écoute moins longtemps et va voir plus vite.
	-- ECOUTE_PRES / ECOUTE_LOIN : secondes figé, tête tournée vers le bruit, selon qu'il est tout près
	-- ou au bout de la portée. C'est le temps laissé au joueur (il voit la tête tourner et reçoit
	-- « Ton bruit a été entendu »). Enquête : vitesse pour aller voir (joueur : marche 16, sprint 32).
	-- Stade 1, marche : 12 studs, à peine plus que sa sensation de proximité (PORTEE_PROXIMITE 10).
	--   On peut donc marcher dans son dos à plus de 12 studs, ou à l'étage (distance verticale x 2).
	--   Écoute longue et enquête lente (12 < 16) : la marche prudente reste viable.
	PORTEE_OUIE_STADE_1 = 12,
	ECOUTE_PRES_STADE_1 = 1.2,
	ECOUTE_LOIN_STADE_1 = 2.0,
	VITESSE_ENQUETE_STADE_1 = 12,
	-- Stade 2, ramasser un objet, retomber d'un saut : un bruit sec, moins portant qu'une course
	PORTEE_OUIE_STADE_2 = 22,
	ECOUTE_PRES_STADE_2 = 0.8,
	ECOUTE_LOIN_STADE_2 = 1.5,
	VITESSE_ENQUETE_STADE_2 = 14,
	-- Stade 3, course : même portée qu'avant (35) pour garder l'équilibrage du sprint (ReglagesSprint)
	PORTEE_OUIE_STADE_3 = 35,
	ECOUTE_PRES_STADE_3 = 0.5,
	ECOUTE_LOIN_STADE_3 = 1.1,
	VITESSE_ENQUETE_STADE_3 = 16,
	-- Stade 4, nettoyage : il réagit presque tout de suite et accourt. Il reste plus lent que le sprint
	-- (32) et la poursuite n'a lieu que s'il VOIT le joueur : fuir dès l'avertissement suffit.
	PORTEE_OUIE_STADE_4 = 40,      -- portée minimale d'un bruit de nettoyage...
	MULTIPLICATEUR_NETTOYAGE = 1.4,-- ... ou portée de l'outil (Outils, x FacteurBruit de la tache) x 1,4 si c'est plus :
	                               --     balai sol 25 -> 40, balai mur 32,5 -> 45,5, aspirateur sol 45 -> 63, mur 58,5 -> 81,9
	ECOUTE_PRES_STADE_4 = 0.3,     -- avant : 0,6 à 1,6 s
	ECOUTE_LOIN_STADE_4 = 0.5,
	VITESSE_ENQUETE_STADE_4 = 19,  -- avant : 14

	-- Vitesses (joueur : 16)
	VITESSE_PATROUILLE = 10,
	VITESSE_ENQUETE = 14,          -- pour aller voir une silhouette entrevue (les bruits ont leur vitesse par stade, plus haut)
	VITESSE_POURSUITE = 24,
	VITESSE_RECHERCHE = 8,

	-- Temps des états
	DUREE_SOUPCON_MAX = 2.5,       -- secondes max à fixer un endroit suspect avant d'aller voir
	DUREE_ALERTE = 0.6,            -- secondes figé quand il repère un joueur (le temps de fuir)
	DUREE_ATTAQUE = 0.9,           -- secondes de l'attaque quand il attrape un joueur
	DUREE_REGARD = 2.5,            -- secondes à regarder autour de lui pendant une recherche
	DUREE_RECHERCHE_MAX = 20,      -- au delà, il abandonne et repatrouille
	TEMPS_POURSUITE_AVEUGLE = 6,   -- secondes max vers la dernière position connue
	ANTICIPATION = 0.8,            -- il vise où le joueur sera dans 0,8 s, d'après sa dernière vitesse vue
	AVANCE_RECHERCHE = 10,         -- il fouille en priorité 10 studs plus loin, dans la direction de fuite
	REPRISE_SANS_ALERTE = 3,       -- s'il revoit le joueur moins de 3 s après l'avoir perdu : pas de nouvelle alerte
	PAUSE_ENTRE_SOUPCONS = 1,      -- secondes minimum entre deux soupçons (évite le va-et-vient)
	DELAI_CONTACT = 2,             -- secondes entre deux contacts avec le même joueur
	REPIT_APRES_CONTACT = 5,       -- après avoir attrapé un joueur, il l'ignore 5 s
	DISTANCE_FUITE_MIN = 40,       -- après une prise, il repart vers un point à plus de 40 studs du joueur
	MEMOIRE_PATROUILLE = 3,        -- il évite de revisiter les 3 derniers points de patrouille

	-- Rythme de calcul
	PERIODE_DECISION = 0.05,       -- secondes entre deux décisions (20 fois par seconde)
	PERIODE_VISION = 0.15,         -- secondes entre deux vérifications de la vue et de l'ouïe
	PERIODE_CONTACT = 0.1,         -- secondes entre deux tests de contact
	PERIODE_RECALCUL = 0.4,        -- secondes entre deux recalculs du chemin vers le joueur
	DEPLACEMENT_RECALCUL = 2,      -- on ne recalcule que si le joueur a bougé de plus de 2 studs
	DISTANCE_DIRECTE = 6,          -- plus près que ça (même étage) : il fonce droit sur le joueur

	-- Contact
	PORTEE_CONTACT = 4,            -- distance de contact à plat (studs)
	HAUTEUR_CONTACT = 8,           -- écart vertical max pour un contact

	-- Chemin
	AGENT_RAYON = 2.5,             -- mains à ~1,9 stud du centre : marge pour que les griffes ne traversent pas les murs près des portes
	AGENT_HAUTEUR = 16,            -- nouveau monstre de 15,6 studs ; les portes font 17,7 (chemins testés OK à 16)
	DISTANCE_POINT = 3.5,          -- à cette distance d'un point du chemin, il vise le suivant
	ECART_POINTS_ESCALIER = 5,     -- un point de guidage tous les 5 studs le long de l'escalier
	DELAI_BLOCAGE = 2,             -- s'il n'avance pas de PROGRES_MIN en 2 s, il est bloqué
	PROGRES_MIN = 0.5,
	DUREE_DECOINCAGE = 0.6,        -- bloqué : il recule en biais pendant 0,6 s puis recalcule
	RECUL_DECOINCAGE = 4,
	ECHECS_AVANT_PAUSE = 3,        -- après 3 calculs de chemin ratés de suite...
	PAUSE_APRES_ECHECS = 1,        -- ... il ne recalcule plus pendant 1 s (économie serveur)

	-- Débogage : affiche l'état au dessus de sa tête, le chemin en points, et écrit les changements d'état
	DEBUG = false,
}

local Reglages = {}

Reglages.DEFAUTS = table.freeze(table.clone(DEFAUTS))

-- Valeurs finales : les défauts, remplacés par les attributs du modèle de même nom et de même type
function Reglages.charger(modele: Instance)
	local valeurs = table.clone(DEFAUTS)
	for nom, defaut in pairs(DEFAUTS) do
		local attribut = modele:GetAttribute(nom)
		if attribut ~= nil then
			if typeof(attribut) == typeof(defaut) and attribut == attribut then -- attribut == attribut : rejette NaN
				valeurs[nom] = attribut
			else
				warn(("Reglages monstre : attribut %s ignoré (type %s attendu)"):format(nom, typeof(defaut)))
			end
		end
	end
	return table.freeze(valeurs)
end

return Reglages
