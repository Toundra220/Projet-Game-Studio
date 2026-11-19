--[[
	Rôle    : IA du monstre du jeu 1 (horreur), machine à états côté serveur :
	          attente   : immobile 7 s au début de la partie (cahier de conception)
	          patrouille: va de point en point dans le manoir (rez-de-chaussée et étage)
	          enquete   : va vers un bruit entendu (pas de course, aspirateur...)
	          alerte    : il vient de repérer un joueur, se fige et se tourne vers lui
	                      (laisse au joueur une fraction de seconde pour réagir)
	          poursuite : court vers le joueur tant qu'il le voit, puis vers l'endroit
	                      où il l'a vu en dernier (il ne connaît pas sa position en direct)
	          recherche : regarde autour de lui, fouille les points proches, puis repatrouille
	          Perception : cône de vue + proximité, rayons vers le torse et la tête,
	          vigilance qui monte plus vite quand le joueur est proche, ouïe.
	          Monte et descend les escaliers. Émet MonstreContact (BindableEvent) au contact.
	          Écoute MonstreBruit (BindableEvent serveur, dans ServerStorage) pour les autres bruits.
	          Indique au client son allure (attribut « Allure ») et son état (attribut « Etat »).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-18
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Réglages : vue
local PORTEE_VUE = 50              -- distance à laquelle il remarque un joueur (studs)
local PORTEE_VUE_POURSUITE = 65    -- une fois en poursuite, il le garde de vue un peu plus loin (évite le clignotement)
local DEMI_ANGLE_VUE = math.rad(65) -- champ de vision : 130° devant lui
local PORTEE_PROXIMITE = 10        -- plus près que ça, il sent le joueur même dans son dos (si pas de mur)
local TEMPS_REACTION_PRES = 0.15   -- secondes pour repérer un joueur tout proche...
local TEMPS_REACTION_LOIN = 1.0    -- ... et un joueur au bout de sa portée de vue
local HAUTEUR_YEUX = 2.5           -- hauteur des yeux au dessus du HumanoidRootPart, si pas de tête trouvée

-- Réglages : ouïe
local SEUIL_VITESSE_BRUIT = 13     -- au dessus de cette vitesse, les pas du joueur font du bruit
local PORTEE_OUIE_PAS = 35         -- distance à laquelle il entend des pas de course
local FACTEUR_ETAGE = 2            -- la distance verticale compte double (le plancher étouffe le bruit)

-- Réglages : vitesses
local VITESSE_PATROUILLE = 10
local VITESSE_ENQUETE = 14
local VITESSE_POURSUITE = 24       -- plus que la course du joueur (16) : il le rattrape même s'il court
local VITESSE_RECHERCHE = 8

-- Réglages : temps
local DELAI_DEPART = 7             -- secondes d'attente au début (mettre 0 pour tester)
local DUREE_ALERTE = 0.6           -- secondes figé quand il repère un joueur
local DUREE_REGARD = 2.5           -- secondes à regarder autour de lui pendant une recherche
local DUREE_RECHERCHE_MAX = 20     -- au delà, il abandonne et repatrouille
local TEMPS_POURSUITE_AVEUGLE = 6  -- secondes max vers la dernière position vue
local ANTICIPATION = 0.8           -- il vise où le joueur sera dans 0,8 s, d'après sa dernière vitesse vue
local REPRISE_SANS_ALERTE = 3      -- s'il revoit le joueur moins de 3 s après l'avoir perdu : pas de nouvelle alerte
local DELAI_CONTACT = 2            -- secondes entre deux contacts avec le même joueur
local REPIT_APRES_CONTACT = 5      -- après avoir attrapé un joueur, il l'ignore 5 s (il ne lui prend pas 3 vies d'un coup)
local PERIODE_VISION = 0.15        -- secondes entre deux vérifications de la vue et de l'ouïe
local PERIODE_RECALCUL = 0.4       -- secondes entre deux recalculs du chemin vers le joueur
local DEPLACEMENT_RECALCUL = 2     -- on ne recalcule que si le joueur a bougé de plus de 2 studs
local DISTANCE_DIRECTE = 6         -- plus près que ça (même étage) : il fonce droit sur le joueur

-- Réglages : suivi du chemin
local PORTEE_CONTACT = 4           -- distance de contact (studs)
local DISTANCE_POINT = 3.5         -- à cette distance d'un point du chemin, il vise le suivant
local ECART_POINTS_ESCALIER = 5    -- un point de guidage tous les 5 studs le long de l'escalier
local DELAI_BLOCAGE = 2            -- s'il n'avance pas de PROGRES_MIN en 2 s, il est bloqué
local PROGRES_MIN = 0.5

local monstre = workspace:WaitForChild("MonstreRodin")
local humanoid = monstre:FindFirstChildOfClass("Humanoid")
local racine = monstre:FindFirstChild("HumanoidRootPart")
assert(humanoid and racine, "MonstreRodin doit avoir un Humanoid et un HumanoidRootPart")
monstre.PrimaryPart = racine
racine:SetNetworkOwner(nil) -- le serveur décide de ses déplacements

local tete = monstre:FindFirstChild("Tete") or monstre:FindFirstChild("Crane") or monstre:FindFirstChild("Head")
if tete and not tete:IsA("BasePart") then
	tete = nil
end

-- Points de patrouille : les pièces du dossier Workspace.PointsPatrouille (rez-de-chaussée et étage).
-- Si le dossier est vide ou absent, le monstre reste sur place.
local POINTS = {}
local dossierPoints = workspace:FindFirstChild("PointsPatrouille")
if dossierPoints then
	for _, p in ipairs(dossierPoints:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(POINTS, p.Position)
		end
	end
end
if #POINTS == 0 then
	warn("MonstreIA : aucun point dans Workspace.PointsPatrouille, le monstre ne patrouille pas")
	POINTS = { racine.Position }
end

-- Escaliers : deux repères invisibles dans le Workspace, EscalierBas (pied de l'escalier, rez-de-chaussée)
-- et EscalierHaut (sommet, à l'étage). Les marches sont trop hautes pour le calcul de chemin habituel :
-- sur l'escalier, le monstre marche donc en ligne droite le long de l'axe EscalierBas -> EscalierHaut.
local ESCALIER_BAS = workspace:FindFirstChild("EscalierBas")
local ESCALIER_HAUT = workspace:FindFirstChild("EscalierHaut")
local SEUIL_ETAGE = nil -- hauteur au dessus de laquelle on est à l'étage
local ZONE_ESCALIER = nil -- rectangle (x, z) couvert par les marches
if ESCALIER_BAS and ESCALIER_HAUT then
	SEUIL_ETAGE = (ESCALIER_BAS.Position.Y + ESCALIER_HAUT.Position.Y) / 2
	local manoir = workspace:FindFirstChild("Manoir")
	local rdc = manoir and manoir:FindFirstChild("RezDeChaussee")
	local escalier = rdc and rdc:FindFirstChild("Escalier")
	if escalier then
		local xmin, xmax, zmin, zmax = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(escalier:GetChildren()) do
			if p:IsA("BasePart") and p.Name:match("^Marche%d+$") then
				xmin = math.min(xmin, p.Position.X - p.Size.X / 2)
				xmax = math.max(xmax, p.Position.X + p.Size.X / 2)
				zmin = math.min(zmin, p.Position.Z - p.Size.Z / 2)
				zmax = math.max(zmax, p.Position.Z + p.Size.Z / 2)
			end
		end
		if xmin < xmax then
			ZONE_ESCALIER = { xmin = xmin, xmax = xmax, zmin = zmin, zmax = zmax }
		end
	end
end
if not (SEUIL_ETAGE and ZONE_ESCALIER) then
	warn("MonstreIA : repères EscalierBas / EscalierHaut ou marches absents, le monstre ne changera pas d'étage")
	SEUIL_ETAGE = nil
end

-- Événements
local contact = ReplicatedStorage:FindFirstChild("MonstreContact")
if not contact then
	contact = Instance.new("BindableEvent")
	contact.Name = "MonstreContact"
	contact.Parent = ReplicatedStorage
end
-- Bruits venant d'autres scripts serveur : MonstreBruit:Fire(position, portee)
-- (aspirateur, objet posé...). BindableEvent : le client ne peut pas le déclencher.
local evenementBruit = ServerStorage:FindFirstChild("MonstreBruit")
if not evenementBruit then
	evenementBruit = Instance.new("BindableEvent")
	evenementBruit.Name = "MonstreBruit"
	evenementBruit.Parent = ServerStorage
end

-- Attributs lus par le client (AnimationMonstre) : envoyés seulement quand ils changent
local function definirAttribut(nom, valeur)
	if monstre:GetAttribute(nom) ~= valeur then
		monstre:SetAttribute(nom, valeur)
	end
end

---------------------------------------------------------------------------
-- Rayons : paramètres créés une seule fois
---------------------------------------------------------------------------

-- Vue : on ignore le monstre et les repères invisibles (points de patrouille, escalier)
local exclusVue = { monstre }
if dossierPoints then table.insert(exclusVue, dossierPoints) end
if ESCALIER_BAS then table.insert(exclusVue, ESCALIER_BAS) end
if ESCALIER_HAUT then table.insert(exclusVue, ESCALIER_HAUT) end
local paramsVue = RaycastParams.new()
paramsVue.FilterType = Enum.RaycastFilterType.Exclude
paramsVue.FilterDescendantsInstances = exclusVue
paramsVue.IgnoreWater = true

-- Sol : on ignore aussi les joueurs
local paramsSol = RaycastParams.new()
paramsSol.FilterType = Enum.RaycastFilterType.Exclude
paramsSol.IgnoreWater = true

local function positionYeux()
	if tete then
		return tete.Position
	end
	return racine.Position + Vector3.new(0, HAUTEUR_YEUX, 0)
end

-- Rien ne bloque la vue entre « depuis » et « point » (sauf le personnage visé lui-même)
local function ligneDeVue(depuis, perso, point)
	local resultat = workspace:Raycast(depuis, point - depuis, paramsVue)
	return resultat == nil or resultat.Instance:IsDescendantOf(perso)
end

-- Hauteur du sol sous une position (on ignore le monstre et les joueurs)
local function hauteurSol(pos)
	local exclus = table.clone(exclusVue)
	for _, joueur in ipairs(Players:GetPlayers()) do
		if joueur.Character then
			table.insert(exclus, joueur.Character)
		end
	end
	paramsSol.FilterDescendantsInstances = exclus
	local resultat = workspace:Raycast(pos, Vector3.new(0, -60, 0), paramsSol)
	return resultat and resultat.Position.Y or pos.Y - 4
end

-- Même position, ramenée au sol (un joueur qui saute est en l'air : on ne peut pas calculer de chemin vers lui)
local function auSol(pos)
	return Vector3.new(pos.X, hauteurSol(pos) + 0.5, pos.Z)
end

-- Dans quelle zone est une position : "rdc", "etage" ou "escalier" (sur les marches)
local function zoneDe(pos)
	if not SEUIL_ETAGE then
		return "rdc"
	end
	local h = hauteurSol(pos)
	local solRdc = ESCALIER_BAS.Position.Y - 0.5   -- les repères sont à 0,5 stud au dessus du sol
	local solEtage = ESCALIER_HAUT.Position.Y - 0.5
	local dansRectangle = pos.X > ZONE_ESCALIER.xmin - 1 and pos.X < ZONE_ESCALIER.xmax + 1
		and pos.Z > ZONE_ESCALIER.zmin - 1 and pos.Z < ZONE_ESCALIER.zmax + 1
	if dansRectangle and h > solRdc + 0.4 and h < solEtage - 0.4 then
		return "escalier"
	end
	return h > SEUIL_ETAGE and "etage" or "rdc"
end

-- Position le long de l'escalier : 0 = pied, 1 = sommet
local function parametreEscalier(pos)
	local axe = ESCALIER_HAUT.Position - ESCALIER_BAS.Position
	local axeH = Vector3.new(axe.X, 0, axe.Z)
	local rel = Vector3.new(pos.X - ESCALIER_BAS.Position.X, 0, pos.Z - ESCALIER_BAS.Position.Z)
	return math.clamp(rel:Dot(axeH) / axeH:Dot(axeH), 0, 1)
end

---------------------------------------------------------------------------
-- Chemin : calcul et suivi continu (pas d'arrêt entre deux points)
---------------------------------------------------------------------------

local points = {}      -- points du chemin en cours : { Position = ..., Action = ... }
local indexPoint = 1   -- prochain point à atteindre
local butActuel = nil  -- destination du chemin en cours (pour le recalculer si bloqué)

-- surveillance du blocage
local suiviIndex, suiviDistance, suiviDepuis = nil, 0, 0
local blocages = 0

-- Chemin « normal » (sol plat) entre deux positions. Renvoie la liste des points ou nil.
local function cheminSimple(depuis, but)
	local chemin = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 12, AgentCanJump = false })
	local ok = pcall(function() chemin:ComputeAsync(depuis, but) end)
	if not ok or chemin.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local liste = {}
	for _, wp in ipairs(chemin:GetWaypoints()) do
		table.insert(liste, { Position = wp.Position, Action = wp.Action })
	end
	return liste
end

-- Points de guidage en ligne droite de « a » vers « b » (pour monter ou descendre l'escalier)
local function ligne(a, b)
	local nombre = math.max(1, math.ceil((b - a).Magnitude / ECART_POINTS_ESCALIER))
	local liste = {}
	for i = 1, nombre do
		table.insert(liste, { Position = a:Lerp(b, i / nombre), Action = Enum.PathWaypointAction.Walk })
	end
	return liste
end

-- Calcule un chemin vers « but ». Renvoie true si un chemin existe.
-- Si le calcul échoue, on garde l'ancien chemin (il continue d'avancer).
local function calculerChemin(but)
	local depuis = racine.Position
	local nouveau

	local zoneDepart, zoneBut = zoneDe(depuis), zoneDe(but)
	if zoneDepart == zoneBut and zoneDepart ~= "escalier" then
		-- même étage, hors escalier : chemin normal
		nouveau = cheminSimple(depuis, but)
		if not nouveau then
			return false
		end
	elseif zoneDepart == "escalier" and zoneBut == "escalier" then
		-- tous les deux sur l'escalier : en ligne droite le long des marches
		local cibleEscalier = ESCALIER_BAS.Position:Lerp(ESCALIER_HAUT.Position, parametreEscalier(but))
		nouveau = ligne(depuis, cibleEscalier)
	else
		-- il faut passer par l'escalier : [chemin jusqu'à l'escalier] + [marches en ligne droite] + [chemin jusqu'au but]
		local function extremite(zone)
			return zone == "rdc" and ESCALIER_BAS.Position or ESCALIER_HAUT.Position
		end
		nouveau = {}
		local debutEscalier
		if zoneDepart == "escalier" then
			debutEscalier = depuis -- il est déjà sur les marches
		else
			debutEscalier = extremite(zoneDepart)
			local avant = cheminSimple(depuis, debutEscalier)
			if not avant then
				return false
			end
			for _, p in ipairs(avant) do
				table.insert(nouveau, p)
			end
		end
		local finEscalier, apres
		if zoneBut == "escalier" then
			finEscalier = ESCALIER_BAS.Position:Lerp(ESCALIER_HAUT.Position, parametreEscalier(but))
		else
			finEscalier = extremite(zoneBut)
			apres = cheminSimple(finEscalier, but)
			if not apres then
				return false
			end
		end
		for _, p in ipairs(ligne(debutEscalier, finEscalier)) do
			table.insert(nouveau, p)
		end
		if apres then
			for i = 2, #apres do
				table.insert(nouveau, apres[i])
			end
		end
	end

	points = nouveau
	indexPoint = math.min(2, #points) -- le premier point est la position actuelle
	butActuel = but
	suiviIndex = nil -- on recommence à surveiller le blocage sur ce nouveau chemin
	return true
end

-- Secours quand le calcul échoue : un seul point, en ligne droite vers le but
local function cheminDirect(but)
	points = { { Position = but, Action = Enum.PathWaypointAction.Walk } }
	indexPoint = 1
	butActuel = but
	suiviIndex = nil
end

local function viderChemin()
	points = {}
	indexPoint = 1
	butActuel = nil
	suiviIndex = nil
	blocages = 0
end

-- Avance vers le point en cours. Renvoie false quand le chemin est terminé
-- (ou abandonné après deux blocages de suite).
local function suivreChemin()
	local point = points[indexPoint]
	if not point then
		return false
	end
	local ecart = point.Position - racine.Position
	local distanceH = Vector3.new(ecart.X, 0, ecart.Z).Magnitude -- on ignore la hauteur
	if distanceH < DISTANCE_POINT then
		indexPoint += 1
		blocages = 0
		point = points[indexPoint]
		if not point then
			return false
		end
		ecart = point.Position - racine.Position
		distanceH = Vector3.new(ecart.X, 0, ecart.Z).Magnitude
	end

	-- Blocage : s'il ne se rapproche pas du point pendant DELAI_BLOCAGE secondes,
	-- on recalcule le chemin ; au deuxième blocage, on abandonne ce but.
	local maintenant = os.clock()
	if suiviIndex ~= indexPoint then
		suiviIndex, suiviDistance, suiviDepuis = indexPoint, distanceH, maintenant
	elseif distanceH < suiviDistance - PROGRES_MIN then
		suiviDistance, suiviDepuis = distanceH, maintenant
	elseif maintenant - suiviDepuis > DELAI_BLOCAGE then
		blocages += 1
		if blocages >= 2 or not butActuel or not calculerChemin(butActuel) then
			viderChemin()
			return false
		end
		point = points[indexPoint]
		if not point then
			return false
		end
	end

	if point.Action == Enum.PathWaypointAction.Jump then
		humanoid.Jump = true
	end
	humanoid:MoveTo(point.Position)
	return true
end

-- S'arrêter sur place et pouvoir se tourner soi-même (regarder autour, faire face au joueur)
local function arreter()
	viderChemin()
	humanoid:MoveTo(racine.Position)
	humanoid.AutoRotate = false
end

local function repartir()
	humanoid.AutoRotate = true
end

-- Angle horizontal (lacet) d'une direction, au sens de CFrame.Angles(0, lacet, 0)
local function lacetDe(direction)
	return math.atan2(-direction.X, -direction.Z)
end

local function orienter(lacet, douceur)
	local voulu = CFrame.new(racine.Position) * CFrame.Angles(0, lacet, 0)
	racine.CFrame = racine.CFrame:Lerp(voulu, douceur)
end

---------------------------------------------------------------------------
-- Perception : écrit des faits dans « memoire », les états les lisent
---------------------------------------------------------------------------

local memoire = {
	cible = nil,              -- joueur repéré (Player)
	voitCible = false,        -- il le voit en ce moment
	dernierePosition = nil,   -- là où il l'a vu en dernier
	derniereVitesse = Vector3.zero,
	finPoursuite = -math.huge, -- moment où il a perdu le joueur
	bruit = nil,              -- position du dernier bruit entendu, pas encore traité
}
local vigilance = {}     -- [joueur] = 0..1 : à 1, il a repéré le joueur
local ignorerJusqua = {} -- [joueur] = moment jusqu'auquel il l'ignore (répit après contact)
local dernierContact = {}
local contactEnAttente = nil -- joueur attrapé, traité par la boucle principale

local etat = nil -- défini plus bas par changerEtat

local function entendre(position, portee)
	local ecart = position - racine.Position
	local distance = Vector3.new(ecart.X, ecart.Y * FACTEUR_ETAGE, ecart.Z).Magnitude
	if distance <= portee then
		memoire.bruit = position
	end
end

evenementBruit.Event:Connect(function(position, portee)
	if typeof(position) ~= "Vector3" or type(portee) ~= "number" or portee ~= portee then
		return
	end
	entendre(position, math.clamp(portee, 0, 200))
end)

local function percevoir(dt, maintenant)
	local yeux = positionYeux()
	local devant = racine.CFrame.LookVector
	local enChasse = etat == "poursuite" or etat == "alerte"
	local portee = enChasse and PORTEE_VUE_POURSUITE or PORTEE_VUE
	local cosAngle = math.cos(DEMI_ANGLE_VUE)

	local meilleur, meilleurScore = nil, math.huge
	local infos = {}

	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local r = perso and perso:FindFirstChild("HumanoidRootPart")
		local h = perso and perso:FindFirstChildOfClass("Humanoid")
		local voit = false
		if r and h and h.Health > 0 and (ignorerJusqua[joueur] or 0) <= maintenant then
			local vecteur = r.Position - yeux
			local distance = vecteur.Magnitude
			-- du moins cher au plus cher : distance, puis cône, puis rayons
			if distance < portee then
				local dansCone = distance < PORTEE_PROXIMITE
					or (distance > 0 and devant:Dot(vecteur / distance) > cosAngle)
				if dansCone then
					local teteJoueur = perso:FindFirstChild("Head")
					voit = ligneDeVue(yeux, perso, r.Position)
						or (teteJoueur ~= nil and ligneDeVue(yeux, perso, teteJoueur.Position))
				end
			end

			if voit then
				-- vigilance : monte vite si le joueur est proche, lentement s'il est loin
				local t = math.clamp((distance - PORTEE_PROXIMITE) / (PORTEE_VUE - PORTEE_PROXIMITE), 0, 1)
				local tempsReaction = TEMPS_REACTION_PRES + (TEMPS_REACTION_LOIN - TEMPS_REACTION_PRES) * t
				vigilance[joueur] = math.min(1, (vigilance[joueur] or 0) + dt / tempsReaction)
				if vigilance[joueur] >= 1 then
					-- il garde de préférence la cible qu'il poursuit déjà
					local score = (joueur == memoire.cible) and -1 or distance
					if score < meilleurScore then
						meilleur, meilleurScore = joueur, score
						infos[joueur] = { position = r.Position, vitesse = r.AssemblyLinearVelocity }
					end
				end
			else
				vigilance[joueur] = math.max(0, (vigilance[joueur] or 0) - dt * 0.5)
			end

			-- ouïe : des pas de course font du bruit (marcher lentement est silencieux)
			local v = r.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > SEUIL_VITESSE_BRUIT and h.FloorMaterial ~= Enum.Material.Air then
				entendre(r.Position, PORTEE_OUIE_PAS)
			end
		end
	end

	if meilleur then
		memoire.cible = meilleur
		memoire.voitCible = true
		memoire.dernierePosition = auSol(infos[meilleur].position)
		memoire.derniereVitesse = infos[meilleur].vitesse
	else
		memoire.voitCible = false
	end
end

local function racineDe(joueur)
	local perso = joueur and joueur.Character
	return perso and perso:FindFirstChild("HumanoidRootPart")
end

-- Contact vérifié en parallèle, plus souvent que la marche
task.spawn(function()
	while true do
		for _, joueur in ipairs(Players:GetPlayers()) do
			local perso = joueur.Character
			local r = perso and perso:FindFirstChild("HumanoidRootPart")
			local h = perso and perso:FindFirstChildOfClass("Humanoid")
			if etat ~= "attente" and r and h and h.Health > 0 and (ignorerJusqua[joueur] or 0) <= os.clock() then
				local ecart = r.Position - racine.Position
				-- distance à plat : sauter au dessus de lui ne permet pas d'esquiver le contact
				if Vector3.new(ecart.X, 0, ecart.Z).Magnitude < PORTEE_CONTACT and math.abs(ecart.Y) < 8 then
					local maintenant = os.clock()
					if not dernierContact[joueur] or maintenant - dernierContact[joueur] > DELAI_CONTACT then
						dernierContact[joueur] = maintenant
						contactEnAttente = joueur
						contact:Fire(joueur)
					end
				end
			end
		end
		task.wait(0.2)
	end
end)

Players.PlayerRemoving:Connect(function(joueur)
	vigilance[joueur] = nil
	ignorerJusqua[joueur] = nil
	dernierContact[joueur] = nil
	if memoire.cible == joueur then
		memoire.cible = nil
		memoire.voitCible = false
	end
end)

---------------------------------------------------------------------------
-- Machine à états
---------------------------------------------------------------------------

local REGLAGES_ETAT = {
	attente   = { vitesse = 0,                  allure = "repos" },
	patrouille = { vitesse = VITESSE_PATROUILLE, allure = "marche" },
	enquete   = { vitesse = VITESSE_ENQUETE,    allure = "marche" },
	alerte    = { vitesse = 0,                  allure = "course" },
	poursuite = { vitesse = VITESSE_POURSUITE,  allure = "course" },
	recherche = { vitesse = VITESSE_RECHERCHE,  allure = "marche" },
}

local debutEtat = 0
local butPatrouille = nil   -- point de patrouille visé (nil = il faut en choisir un)
local cheminPret = false    -- le chemin vers le but de l'état est calculé
local butEnquete = nil
local dernierCalcul = 0
local perduDepuis = nil     -- en poursuite : moment où il a perdu le joueur de vue
local recherche = { centre = nil, buts = {}, index = 0, phase = "regard", debutPhase = 0, lacetBase = 0 }

-- Seul endroit où l'état change : sortie, puis entrée du nouvel état
local function changerEtat(nouveau)
	if nouveau == etat then
		return
	end
	repartir()
	viderChemin()
	cheminPret = false
	etat = nouveau
	debutEtat = os.clock()

	local reglages = REGLAGES_ETAT[nouveau]
	humanoid.WalkSpeed = reglages.vitesse
	definirAttribut("Allure", reglages.allure)
	definirAttribut("Etat", nouveau)

	if nouveau == "attente" or nouveau == "alerte" then
		arreter()
	elseif nouveau == "patrouille" then
		butPatrouille = nil
		memoire.cible = nil
	elseif nouveau == "poursuite" then
		perduDepuis = nil
		dernierCalcul = 0
	end
end

-- Recherche autour d'un endroit : regarder autour, puis fouiller les 2 points de patrouille les plus proches
local function commencerRecherche(centre)
	changerEtat("recherche")
	local tries = table.clone(POINTS)
	table.sort(tries, function(a, b)
		return (a - centre).Magnitude < (b - centre).Magnitude
	end)
	recherche.centre = centre
	recherche.buts = { tries[1], tries[2] }
	recherche.index = 0
	recherche.phase = "regard"
	recherche.debutPhase = os.clock()
	recherche.lacetBase = lacetDe(racine.CFrame.LookVector)
	arreter()
end

-- Choisit un nouveau point de patrouille au hasard (différent du précédent)
local function pointAuHasard(precedent)
	if #POINTS == 1 then
		return POINTS[1]
	end
	local choix = POINTS[math.random(#POINTS)]
	while choix == precedent do
		choix = POINTS[math.random(#POINTS)]
	end
	return choix
end

local function decider(maintenant)
	local dansEtat = maintenant - debutEtat

	if etat == "attente" then
		if dansEtat >= DELAI_DEPART then
			changerEtat("patrouille")
		end
		return
	end

	-- il vient d'attraper un joueur : il le lâche quelques secondes
	if contactEnAttente then
		local joueur = contactEnAttente
		contactEnAttente = nil
		ignorerJusqua[joueur] = maintenant + REPIT_APRES_CONTACT
		vigilance[joueur] = 0
		if memoire.cible == joueur then
			memoire.voitCible = false
			memoire.finPoursuite = -math.huge
			changerEtat("patrouille")
			return
		end
	end

	-- sortie commune : il voit un joueur (priorité sur tout le reste)
	if memoire.voitCible and etat ~= "poursuite" and etat ~= "alerte" then
		if maintenant - memoire.finPoursuite < REPRISE_SANS_ALERTE then
			changerEtat("poursuite") -- il vient de le perdre : il reprend tout de suite
		else
			changerEtat("alerte")
		end
		return
	end

	-- sortie commune : il entend un bruit (sauf s'il chasse déjà)
	if memoire.bruit and etat ~= "poursuite" and etat ~= "alerte" then
		local bruit = memoire.bruit
		memoire.bruit = nil
		if etat ~= "enquete" or (bruit - butEnquete).Magnitude > 4 then
			butEnquete = bruit
			changerEtat("enquete")
			cheminPret = false -- nouveau bruit pendant l'enquête : nouveau chemin
		end
	elseif etat == "poursuite" or etat == "alerte" then
		memoire.bruit = nil
	end

	if etat == "alerte" then
		-- figé, il se tourne vers le joueur : le joueur a le temps de comprendre et de fuir
		if memoire.dernierePosition then
			local ecart = memoire.dernierePosition - racine.Position
			if Vector3.new(ecart.X, 0, ecart.Z).Magnitude > 0.1 then
				orienter(lacetDe(ecart), 0.35)
			end
		end
		if dansEtat >= DUREE_ALERTE then
			changerEtat("poursuite")
		end

	elseif etat == "poursuite" then
		local r = racineDe(memoire.cible)
		if memoire.voitCible and r then
			-- il le voit : il va vers sa position réelle
			perduDepuis = nil
			local cibleP = memoire.dernierePosition or auSol(r.Position) -- au sol, même s'il saute
			local ecart = cibleP - racine.Position
			if Vector3.new(ecart.X, 0, ecart.Z).Magnitude < DISTANCE_DIRECTE and zoneDe(cibleP) == zoneDe(racine.Position) then
				viderChemin()
				humanoid:MoveTo(cibleP) -- tout près : droit sur lui, sans calcul de chemin
			else
				local cheminFini = points[indexPoint] == nil
				if maintenant - dernierCalcul > PERIODE_RECALCUL
					and (cheminFini or not butActuel or (cibleP - butActuel).Magnitude > DEPLACEMENT_RECALCUL) then
					dernierCalcul = maintenant
					if not calculerChemin(cibleP) and (cheminFini or zoneDe(cibleP) == zoneDe(racine.Position)) then
						cheminDirect(cibleP) -- calcul raté : il fonce droit au lieu de s'arrêter
					end
				end
				suivreChemin()
			end
		else
			-- il ne le voit plus : il va là où il pense le trouver, sans tricher
			if not perduDepuis then
				perduDepuis = maintenant
				local v = memoire.derniereVitesse
				local estimee = memoire.dernierePosition + Vector3.new(v.X, 0, v.Z) * ANTICIPATION
				if not calculerChemin(auSol(estimee)) and not calculerChemin(memoire.dernierePosition) then
					cheminDirect(memoire.dernierePosition)
				end
			end
			if (not suivreChemin() and dansEtat > 0.4) or maintenant - perduDepuis > TEMPS_POURSUITE_AVEUGLE then
				memoire.finPoursuite = maintenant
				commencerRecherche(memoire.dernierePosition)
			end
		end

	elseif etat == "enquete" then
		if not cheminPret then
			if calculerChemin(butEnquete) then
				cheminPret = true
			else
				changerEtat("patrouille") -- bruit inaccessible
				return
			end
		end
		if not suivreChemin() then
			commencerRecherche(butEnquete) -- arrivé à l'endroit du bruit : il fouille
		end

	elseif etat == "recherche" then
		if dansEtat > DUREE_RECHERCHE_MAX then
			changerEtat("patrouille")
			return
		end
		if recherche.phase == "regard" then
			-- il tourne la tête et le corps à gauche puis à droite
			local t = maintenant - recherche.debutPhase
			orienter(recherche.lacetBase + math.sin(t * 1.6) * math.rad(70), 0.25)
			if t >= DUREE_REGARD then
				repartir()
				recherche.index += 1
				local but = recherche.buts[recherche.index]
				if not but then
					changerEtat("patrouille")
				elseif calculerChemin(but) then
					recherche.phase = "marche"
				else
					recherche.debutPhase = maintenant -- point inaccessible : il regarde encore, puis passe au suivant
					humanoid.AutoRotate = false
				end
			end
		elseif not suivreChemin() then
			recherche.phase = "regard"
			recherche.debutPhase = maintenant
			recherche.lacetBase = lacetDe(racine.CFrame.LookVector)
			arreter()
		end

	elseif etat == "patrouille" then
		if not butPatrouille then
			butPatrouille = pointAuHasard(butPatrouille)
			cheminPret = false
		end
		if not cheminPret then
			if calculerChemin(butPatrouille) then
				cheminPret = true
			else
				butPatrouille = pointAuHasard(butPatrouille) -- point inaccessible : on en prend un autre
			end
		end
		if cheminPret and not suivreChemin() then
			butPatrouille = nil -- point atteint (ou bloqué) : on en choisira un autre
			cheminPret = false
		end
	end
end

-- Boucle principale : perception 6 à 7 fois par seconde, décision et marche 20 fois par seconde
changerEtat("attente")
local derniereVision = os.clock()
while true do
	local maintenant = os.clock()
	if etat ~= "attente" and maintenant - derniereVision >= PERIODE_VISION then
		percevoir(maintenant - derniereVision, maintenant)
		derniereVision = maintenant
	elseif etat == "attente" then
		derniereVision = maintenant
	end
	decider(maintenant)
	task.wait(0.05)
end
