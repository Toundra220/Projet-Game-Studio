--[[
	Rôle    : IA du monstre du jeu 1 (horreur). Patrouille entre des points du manoir (rez-de-chaussée
	          et étage), poursuit le joueur qu'il voit, continue de le suivre quelques secondes
	          après l'avoir perdu de vue, monte et descend les escaliers, et indique son allure
	          (marche ou course) au client.
	          Il avance sans s'arrêter : le chemin est suivi point par point en continu.
	          Émet MonstreContact (BindableEvent) au contact.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-17
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Réglages
local PORTEE_VUE = 50            -- distance à laquelle le monstre voit le joueur (studs)
local PORTEE_CONTACT = 4         -- distance de contact (studs)
local VITESSE_PATROUILLE = 10
local VITESSE_POURSUITE = 24     -- plus que la course du joueur (16) : il le rattrape même s'il court normalement
local TEMPS_PERDU = 8            -- secondes qu'il continue de suivre le joueur après l'avoir perdu de vue
local DELAI_CONTACT = 2          -- secondes entre deux contacts avec le même joueur
local PERIODE_RECALCUL = 0.4     -- secondes entre deux recalculs du chemin vers le joueur
local DISTANCE_POINT = 3.5       -- à cette distance d'un point du chemin, il vise le suivant
local ECART_POINTS_ESCALIER = 5  -- un point de guidage tous les 5 studs le long de l'escalier

local monstre = workspace:WaitForChild("MonstreRodin")
local humanoid = monstre:FindFirstChildOfClass("Humanoid")
local racine = monstre:FindFirstChild("HumanoidRootPart")
assert(humanoid and racine, "MonstreRodin doit avoir un Humanoid et un HumanoidRootPart")
monstre.PrimaryPart = racine

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

-- Animations : le serveur dit l'allure (marche ou course) dans l'attribut « Allure »,
-- le LocalScript AnimationMonstre fait bouger le squelette chez chaque joueur.
racine:SetNetworkOwner(nil)
local allureActuelle = nil
local function jouer(allure)
	if allure ~= allureActuelle then -- on n'envoie le changement qu'une seule fois
		allureActuelle = allure
		monstre:SetAttribute("Allure", allure)
	end
end

local contact = ReplicatedStorage:FindFirstChild("MonstreContact")
if not contact then
	contact = Instance.new("BindableEvent")
	contact.Name = "MonstreContact"
	contact.Parent = ReplicatedStorage
end

local function joueurVu()
	local meilleur, meilleureDistance = nil, PORTEE_VUE
	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local r = perso and perso:FindFirstChild("HumanoidRootPart")
		local h = perso and perso:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			local vecteur = r.Position - racine.Position
			local distance = vecteur.Magnitude
			if distance < meilleureDistance then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { monstre, perso }
				-- pas de mur entre le monstre et le joueur : il a une ligne de vue
				if not workspace:Raycast(racine.Position, vecteur, params) then
					meilleur, meilleureDistance = perso, distance
				end
			end
		end
	end
	return meilleur
end

-- Hauteur du sol sous une position (on ignore le monstre et les joueurs)
local function hauteurSol(pos)
	local exclus = { monstre }
	for _, joueur in ipairs(Players:GetPlayers()) do
		if joueur.Character then
			table.insert(exclus, joueur.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclus
	local resultat = workspace:Raycast(pos, Vector3.new(0, -60, 0), params)
	return resultat and resultat.Position.Y or pos.Y - 4
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

-- Suivi de chemin continu : on calcule la liste des points, puis on la parcourt
-- sans jamais s'arrêter entre deux points (c'est ce qui évite les saccades).
local points = {}      -- points du chemin en cours : { Position = ..., Action = ... }
local indexPoint = 1   -- prochain point à atteindre

-- Chemin « normal » (sol plat) entre deux positions. Renvoie la liste des points ou nil.
-- Pas de saut : les escaliers sont gérés à part, le reste du sol est plat.
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
	return true
end

-- Avance vers le point en cours. Renvoie false quand le chemin est terminé.
local function suivreChemin()
	local point = points[indexPoint]
	if not point then
		return false
	end
	local ecart = point.Position - racine.Position
	if Vector3.new(ecart.X, 0, ecart.Z).Magnitude < DISTANCE_POINT then -- on ignore la hauteur
		indexPoint += 1
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

local dernierContact = {}

local function verifierContact()
	for _, joueur in ipairs(Players:GetPlayers()) do
		local perso = joueur.Character
		local r = perso and perso:FindFirstChild("HumanoidRootPart")
		local h = perso and perso:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			if (r.Position - racine.Position).Magnitude < PORTEE_CONTACT then
				local maintenant = os.clock()
				if not dernierContact[joueur] or maintenant - dernierContact[joueur] > DELAI_CONTACT then
					dernierContact[joueur] = maintenant
					contact:Fire(joueur)
				end
			end
		end
	end
end

-- Contact vérifié en parallèle, plus souvent que la marche
task.spawn(function()
	while true do
		verifierContact()
		task.wait(0.2)
	end
end)

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

-- Boucle principale : patrouille, poursuite, suivi après perte de vue
local etat = "patrouille"
local butPatrouille = nil   -- point de patrouille visé (nil = il faut en choisir un)
local cheminPret = false    -- le chemin vers butPatrouille est calculé
local dernierVu = 0
local cible = nil
local derniereVision = 0
local dernierCalcul = 0

while true do
	local maintenant = os.clock()

	-- la vue (rayons) est vérifiée 5 fois par seconde, pas à chaque pas
	if maintenant - derniereVision > 0.2 then
		derniereVision = maintenant
		local vu = joueurVu()
		if vu then
			etat = "poursuite"
			cible = vu
			dernierVu = maintenant
		end
	end

	if etat == "poursuite" and cible and cible:FindFirstChild("HumanoidRootPart") and maintenant - dernierVu < TEMPS_PERDU then
		-- il voit le joueur, ou il le suit encore pendant TEMPS_PERDU secondes
		humanoid.WalkSpeed = VITESSE_POURSUITE
		jouer("course")
		cheminPret = false
		if maintenant - dernierCalcul > PERIODE_RECALCUL then
			dernierCalcul = maintenant
			calculerChemin(cible.HumanoidRootPart.Position)
		end
		suivreChemin()
	else
		etat = "patrouille"
		cible = nil
		humanoid.WalkSpeed = VITESSE_PATROUILLE
		jouer("marche")
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
			butPatrouille = nil -- point atteint : on en choisira un autre
			cheminPret = false
		end
	end
	task.wait(0.05)
end
