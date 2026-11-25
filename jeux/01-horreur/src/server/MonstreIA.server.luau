--[[
	Rôle    : IA du monstre du jeu 1 (horreur), machine à états côté serveur.
	          attente   : immobile, puis part 7 s après l'apparition du premier joueur
	          patrouille: va de point en point (rez-de-chaussée et étage), évite les derniers visités
	          soupcon   : il a entrevu quelqu'un : il s'arrête, fixe l'endroit, la tête penchée ;
	                      si le joueur reste visible -> alerte, s'il se cache -> il va voir (enquete)
	          ecoute    : il vient d'entendre un bruit : il s'arrête 0,6 à 1,6 s (plus le bruit est loin, plus
	                      c'est long), la tête tournée vers lui (le client l'anime comme « soupcon »), puis
	                      il va voir (enquete). Le joueur qui fait le bruit en nettoyant est averti (attribut
	                      MonstreAttire sur son Player, affiché par Taches/AvertissementBruit).
	          enquete   : va vers un bruit (pas de course, balai, aspirateur...) ou vers ce qu'il a entrevu
	          alerte    : il vient de repérer un joueur, se fige et se tourne vers lui
	                      (laisse au joueur une fraction de seconde pour réagir)
	          poursuite : court vers le joueur tant qu'il le voit ; sinon vers sa position estimée,
	                      et suit les bruits qu'il fait en fuyant (il ne connaît pas sa position en direct)
	          recherche : regarde autour, fouille les points proches dans la direction de fuite, repatrouille
	          attaque   : il a attrapé un joueur : courte attaque, puis il le lâche et s'éloigne
	          Sens : Monstre/Perception. Chemin : Monstre/Deplacement. Chiffres : Monstre/Reglages
	          (modifiables par attributs sur Workspace.MonstreRodin, ex. DELAI_DEPART, DEBUG).
	          Émet MonstreContact (BindableEvent, ReplicatedStorage) au contact : Vies.server retire une vie.
	          Écoute MonstreBruit (BindableEvent, ServerStorage) : MonstreBruit:Fire(position, portee, joueur?).
	          Tout nettoyage en émet un (Outils/Utilisations/Nettoyage) : le monstre vient voir les taches
	          qu'on nettoie, avec l'imprécision de Perception.entendre. Le client ne peut pas en envoyer.
	          Attributs lus par le client : Etat, Allure, CibleId (UserId poursuivi, 0 sinon),
	          Regard (Vector3 que la tête fixe, absent sinon).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-18 (refonte en modules : 2026-11-24 ; écoute et bruits de nettoyage : 2026-11-25)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local dossierModules = script.Parent:WaitForChild("Monstre")
local Reglages = require(dossierModules:WaitForChild("Reglages"))
local Terrain = require(dossierModules:WaitForChild("Terrain"))
local Perception = require(dossierModules:WaitForChild("Perception"))
local Deplacement = require(dossierModules:WaitForChild("Deplacement"))
-- nom de l'attribut d'avertissement du joueur : partagé avec le client (Taches/AvertissementBruit)
local ATTRIBUT_AVERTISSEMENT = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Taches"):WaitForChild("ReglagesTaches")
).ATTRIBUT_AVERTISSEMENT

local monstre = workspace:WaitForChild("MonstreRodin")
local humanoid = monstre:FindFirstChildOfClass("Humanoid")
local racine = monstre:FindFirstChild("HumanoidRootPart")
assert(humanoid and racine, "MonstreRodin doit avoir un Humanoid et un HumanoidRootPart")
monstre.PrimaryPart = racine

local R = Reglages.charger(monstre)

local tete = monstre:FindFirstChild("Tete") or monstre:FindFirstChild("Crane") or monstre:FindFirstChild("Head")
if tete and not tete:IsA("BasePart") then
	tete = nil
end

-- Un monstre ne s'assoit pas sur les chaises du manoir et ne trébuche pas
for _, etatHumanoid in { Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll } do
	humanoid:SetStateEnabled(etatHumanoid, false)
end

-- Le serveur décide de ses déplacements. Re-vérifié régulièrement : la propriété réseau
-- peut repasser automatiquement à un client proche (et SetNetworkOwner échoue si la racine est ancrée).
local function garderProprieteServeur()
	pcall(function()
		if racine:GetNetworkOwner() ~= nil then
			racine:SetNetworkOwner(nil)
		end
	end)
end
pcall(function()
	racine:SetNetworkOwner(nil)
end)
task.spawn(function()
	while monstre.Parent do
		task.wait(2)
		garderProprieteServeur()
	end
end)

-- Points de patrouille : les pièces du dossier Workspace.PointsPatrouille.
-- Si le dossier est vide ou absent, le monstre reste sur place.
local POINTS = {}
local dossierPoints = workspace:FindFirstChild("PointsPatrouille")
if dossierPoints then
	for _, p in dossierPoints:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(POINTS, p.Position)
		end
	end
end
if #POINTS == 0 then
	warn("MonstreIA : aucun point dans Workspace.PointsPatrouille, le monstre ne patrouille pas")
	POINTS = { racine.Position }
end

-- Ce que ses rayons ignorent : lui-même et les repères invisibles
local exclus = { monstre }
if dossierPoints then table.insert(exclus, dossierPoints) end
local repereBas, repereHaut = workspace:FindFirstChild("EscalierBas"), workspace:FindFirstChild("EscalierHaut")
if repereBas then table.insert(exclus, repereBas) end
if repereHaut then table.insert(exclus, repereHaut) end

local terrain = Terrain.nouveau(exclus)
local perception = Perception.nouveau({
	reglages = R, racine = racine, tete = tete, terrain = terrain, exclusVue = exclus,
})
local deplacement = Deplacement.nouveau({
	reglages = R, humanoid = humanoid, racine = racine, terrain = terrain,
})
local memoire = perception.memoire

-- Événements (trouver ou créer, sans attente entre les deux : même motif que EvenementsServeur)
local contact = ReplicatedStorage:FindFirstChild("MonstreContact")
if not contact then
	contact = Instance.new("BindableEvent")
	contact.Name = "MonstreContact"
	contact.Parent = ReplicatedStorage
end
-- BindableEvent dans ServerStorage : le client ne peut ni le voir ni le déclencher
local evenementBruit = ServerStorage:FindFirstChild("MonstreBruit")
if not evenementBruit then
	evenementBruit = Instance.new("BindableEvent")
	evenementBruit.Name = "MonstreBruit"
	evenementBruit.Parent = ServerStorage
end

local function estFini(x)
	return type(x) == "number" and x == x and math.abs(x) < 1e6
end

local etat = nil -- défini par changerEtat

evenementBruit.Event:Connect(function(position, portee, source)
	if typeof(position) ~= "Vector3" or not estFini(portee)
		or not (estFini(position.X) and estFini(position.Y) and estFini(position.Z)) then
		return
	end
	if etat == "attente" then
		return
	end
	-- source : le joueur qui fait le bruit (facultatif). On ne fait confiance qu'à un vrai joueur présent.
	if typeof(source) ~= "Instance" or not source:IsA("Player") or source.Parent ~= Players then
		source = nil
	end
	local entendu = perception.entendre(position, math.clamp(portee, 0, R.PORTEE_BRUIT_MAX), source)
	if R.DEBUG then
		print(("[Monstre] %.2f  bruit (portée %.0f) : %s"):format(os.clock(), portee, entendu and "entendu" or "trop loin"))
	end
end)

-- Attributs lus par le client : envoyés seulement quand ils changent
local function definirAttribut(nom, valeur)
	if monstre:GetAttribute(nom) ~= valeur then
		monstre:SetAttribute(nom, valeur)
	end
end

local function racineDe(joueur)
	local perso = joueur and joueur.Character
	return perso and perso:FindFirstChild("HumanoidRootPart")
end

-- Avertissement du joueur dont le bruit attire le monstre (états ecoute et enquete) :
-- un attribut booléen sur son Player, répliqué au client qui l'affiche (pas de RemoteEvent).
-- Un seul joueur à la fois : celui du dernier bruit entendu.
local joueurPrevenu = nil
local function prevenir(joueur)
	if joueur == joueurPrevenu then
		return
	end
	if joueurPrevenu and joueurPrevenu.Parent then
		joueurPrevenu:SetAttribute(ATTRIBUT_AVERTISSEMENT, nil)
	end
	joueurPrevenu = joueur
	if joueur then
		joueur:SetAttribute(ATTRIBUT_AVERTISSEMENT, true)
	end
end

---------------------------------------------------------------------------
-- Contact : vérifié en parallèle, plus souvent que la décision
---------------------------------------------------------------------------

local dernierContact = {}
local contactsEnAttente = {} -- joueurs attrapés, traités par la machine à états

task.spawn(function()
	while true do
		if etat ~= "attente" and etat ~= "attaque" then
			local maintenant = os.clock()
			for _, joueur in Players:GetPlayers() do
				local perso = joueur.Character
				local r = perso and perso:FindFirstChild("HumanoidRootPart")
				local h = perso and perso:FindFirstChildOfClass("Humanoid")
				if r and h and h.Health > 0 and not perception.estIgnore(joueur, maintenant) then
					local ecart = r.Position - racine.Position
					-- distance à plat : sauter au dessus de lui ne permet pas d'esquiver
					if Vector3.new(ecart.X, 0, ecart.Z).Magnitude < R.PORTEE_CONTACT and math.abs(ecart.Y) < R.HAUTEUR_CONTACT then
						if not dernierContact[joueur] or maintenant - dernierContact[joueur] > R.DELAI_CONTACT then
							dernierContact[joueur] = maintenant
							-- répit posé tout de suite : pas de second contact avant que la décision passe
							perception.ignorer(joueur, maintenant + R.REPIT_APRES_CONTACT)
							table.insert(contactsEnAttente, { joueur = joueur, position = r.Position })
							contact:Fire(joueur)
						end
					end
				end
			end
		end
		task.wait(R.PERIODE_CONTACT)
	end
end)

Players.PlayerRemoving:Connect(function(joueur)
	perception.oublier(joueur)
	dernierContact[joueur] = nil
	if joueur == joueurPrevenu then
		joueurPrevenu = nil
	end
end)

---------------------------------------------------------------------------
-- Machine à états
---------------------------------------------------------------------------

-- calme : bruits et soupçons peuvent l'interrompre. chasse : il est sur un joueur.
-- publie : nom d'état envoyé au client à la place du vrai (le client anime « soupcon » : figé, tête penchée).
local ETATS = {
	attente    = { vitesse = 0,                    allure = "repos" },
	patrouille = { vitesse = R.VITESSE_PATROUILLE, allure = "marche", calme = true },
	soupcon    = { vitesse = 0,                    allure = "repos" },
	ecoute     = { vitesse = 0,                    allure = "repos", calme = true, publie = "soupcon" },
	enquete    = { vitesse = R.VITESSE_ENQUETE,    allure = "marche", calme = true },
	alerte     = { vitesse = 0,                    allure = "course", chasse = true },
	poursuite  = { vitesse = R.VITESSE_POURSUITE,  allure = "course", chasse = true },
	recherche  = { vitesse = R.VITESSE_RECHERCHE,  allure = "marche", calme = true },
	attaque    = { vitesse = 0,                    allure = "course", chasse = true },
}

local debutEtat = 0
local regard = nil            -- point que la tête fixe (attribut Regard)

-- données des états
local premierJoueurVu = nil   -- attente : moment où un joueur est apparu
local butPatrouille, cheminPret = nil, false
local visites = {}            -- derniers points de patrouille visités
local loinDe = nil            -- après une prise : patrouiller loin de cette position
local enquete = { estime = nil, brut = nil, essaiBrut = false }
local ecoute = { estime = nil, brut = nil, source = nil, duree = 0 } -- bruit entendu, avant d'aller voir
local dernierBruitSuivi = { brut = nil, instant = -math.huge } -- dernier endroit où il est allé voir (bruit ou silhouette)
local finSoupcon = -math.huge
local perduDepuis = nil       -- poursuite : moment où il a perdu le joueur de vue
local piste = nil             -- poursuite : meilleure idée de là où est le joueur
local dernierCalcul = 0
local recherche = { buts = {}, index = 0, phase = "regard", debutPhase = 0, lacetBase = 0 }
local attaque = { position = nil }

-- Seul endroit où l'état change : sortie commune, puis entrée du nouvel état.
-- Les entrées ne rappellent jamais changerEtat (pas de ré-entrée).
local function changerEtat(nouveau)
	if nouveau == etat then
		return
	end
	if R.DEBUG then
		print(("[Monstre] %.2f  %s -> %s"):format(os.clock(), tostring(etat), nouveau))
	end
	if etat == "soupcon" then
		finSoupcon = os.clock()
	end
	deplacement.repartir()
	deplacement.vider()
	cheminPret = false
	regard = nil
	etat = nouveau
	debutEtat = os.clock()

	-- le joueur n'est averti que tant que le monstre vient à cause de son bruit (ecoute, puis enquete)
	if nouveau ~= "ecoute" and nouveau ~= "enquete" then
		prevenir(nil)
	end

	local def = ETATS[nouveau]
	humanoid.WalkSpeed = def.vitesse
	definirAttribut("Allure", def.allure)
	definirAttribut("Etat", def.publie or nouveau)

	if nouveau == "attente" or nouveau == "alerte" or nouveau == "soupcon" or nouveau == "ecoute" or nouveau == "attaque" then
		deplacement.arreter()
	elseif nouveau == "patrouille" then
		butPatrouille = nil
		memoire.cible = nil
	elseif nouveau == "poursuite" then
		perduDepuis = nil
		piste = nil
		dernierCalcul = 0
	end
end

-- Va voir un endroit (bruit ou silhouette entrevue). source : le joueur dont le bruit l'attire (ou nil)
local function commencerEnquete(estime, brut, source)
	changerEtat("enquete")
	enquete.estime, enquete.brut, enquete.essaiBrut = estime, brut, false
	dernierBruitSuivi.brut, dernierBruitSuivi.instant = brut, os.clock()
	cheminPret = false
	prevenir(source)
end

-- Vient d'entendre un bruit : il s'arrête un instant, la tête tournée vers lui, avant d'aller voir.
-- Plus le bruit est proche, plus il réagit vite (comme pour sa vue : TEMPS_REACTION_PRES / LOIN).
-- C'est le temps de réaction laissé au joueur : il voit sa tête tourner et reçoit l'avertissement.
local function commencerEcoute(bruit)
	changerEtat("ecoute")
	ecoute.estime, ecoute.brut, ecoute.source = bruit.estime, bruit.brut, bruit.source
	ecoute.duree = R.DUREE_ECOUTE_PRES + (R.DUREE_ECOUTE_LOIN - R.DUREE_ECOUTE_PRES) * (1 - bruit.intensite)
	prevenir(bruit.source)
end

-- Recherche autour d'un endroit : regarder autour, puis fouiller les 2 points de patrouille
-- les plus proches de l'endroit où le joueur allait (centre + direction de fuite)
local function commencerRecherche(centre, directionFuite)
	changerEtat("recherche")
	local vise = centre
	local fuite = directionFuite and Vector3.new(directionFuite.X, 0, directionFuite.Z)
	if fuite and fuite.Magnitude > 1 then
		vise = centre + fuite.Unit * R.AVANCE_RECHERCHE
	end
	local function distance(p)
		local e = p - vise
		return Vector3.new(e.X, e.Y * R.FACTEUR_ETAGE, e.Z).Magnitude
	end
	local tries = table.clone(POINTS)
	table.sort(tries, function(a, b)
		return distance(a) < distance(b)
	end)
	recherche.buts = { tries[1], tries[2] }
	recherche.index = 0
	recherche.phase = "regard"
	recherche.debutPhase = os.clock()
	recherche.lacetBase = deplacement.lacetDe(racine.CFrame.LookVector)
	deplacement.arreter()
end

-- Choisit un point de patrouille : pas un des derniers visités, et loin du joueur
-- qu'il vient d'attraper s'il y en a un
local function choisirPointPatrouille()
	if #POINTS == 1 then
		return POINTS[1]
	end
	local candidats = {}
	for _, p in POINTS do
		local recent = table.find(visites, p) ~= nil
		local tropPres = loinDe and (p - loinDe).Magnitude < R.DISTANCE_FUITE_MIN
		if not recent and not tropPres then
			table.insert(candidats, p)
		end
	end
	if #candidats == 0 then
		for _, p in POINTS do
			if p ~= visites[#visites] then
				table.insert(candidats, p)
			end
		end
	end
	return candidats[math.random(#candidats)]
end

local function noterVisite(p)
	table.insert(visites, p)
	while #visites > math.min(R.MEMOIRE_PATROUILLE, #POINTS - 1) do
		table.remove(visites, 1)
	end
end

local MAJ = {}

function MAJ.attente(maintenant)
	-- le compte à rebours démarre quand un joueur est vraiment dans le manoir
	if not premierJoueurVu then
		for _, joueur in Players:GetPlayers() do
			local perso = joueur.Character
			local h = perso and perso:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 and perso:FindFirstChild("HumanoidRootPart") then
				premierJoueurVu = maintenant
				break
			end
		end
		return
	end
	if maintenant - premierJoueurVu >= R.DELAI_DEPART then
		changerEtat("patrouille")
	end
end

function MAJ.patrouille()
	if not butPatrouille then
		butPatrouille = choisirPointPatrouille()
		cheminPret = false
	end
	if not cheminPret then
		if deplacement.calculer(butPatrouille) then
			cheminPret = true
		else
			noterVisite(butPatrouille) -- inaccessible : on ne le retente pas tout de suite
			butPatrouille = nil
			return
		end
	end
	if not deplacement.suivre() then
		noterVisite(butPatrouille) -- point atteint (ou bloqué) : on en choisira un autre
		butPatrouille = nil
		cheminPret = false
		loinDe = nil
	end
end

function MAJ.soupcon(maintenant, dansEtat)
	-- figé, il fixe l'endroit suspect ; la perception continue (le joueur est maintenant au centre de sa vue)
	if memoire.indice then
		deplacement.faireFace(memoire.indice, 0.2)
		regard = memoire.indice + Vector3.new(0, 3, 0)
	end
	local perdu = not memoire.indiceVu and maintenant - debutEtat > 0.6
	if perdu or dansEtat > R.DUREE_SOUPCON_MAX then
		if memoire.indice then
			commencerEnquete(memoire.indice, memoire.indice) -- il a vu quelque chose : il va voir
		else
			changerEtat("patrouille")
		end
	end
end

function MAJ.ecoute(_maintenant, dansEtat)
	-- figé, la tête tournée vers le bruit : le joueur voit qu'il a été entendu et peut s'arrêter ou fuir
	deplacement.faireFace(ecoute.brut, 0.3)
	regard = ecoute.brut + Vector3.new(0, 3, 0)
	if dansEtat >= ecoute.duree then
		commencerEnquete(ecoute.estime, ecoute.brut, ecoute.source)
	end
end

function MAJ.enquete()
	if not cheminPret then
		if deplacement.calculer(enquete.estime) then
			cheminPret = true
		elseif not enquete.essaiBrut and deplacement.calculer(enquete.brut) then
			-- la position estimée est dans un mur : il va vers le vrai endroit
			enquete.essaiBrut = true
			cheminPret = true
		else
			changerEtat("patrouille") -- endroit inaccessible
			return
		end
	end
	if not deplacement.suivre() then
		commencerRecherche(enquete.estime, nil) -- arrivé : il fouille du regard
	end
end

function MAJ.alerte(_maintenant, dansEtat)
	-- figé, il se tourne vers le joueur : le joueur a le temps de comprendre et de fuir
	if memoire.dernierePosition then
		deplacement.faireFace(memoire.dernierePosition, 0.35)
		regard = memoire.dernierePosition + Vector3.new(0, 3, 0)
	end
	if dansEtat >= R.DUREE_ALERTE then
		changerEtat("poursuite")
	end
end

function MAJ.poursuite(maintenant, dansEtat)
	local r = racineDe(memoire.cible)
	if memoire.voitCible and r then
		-- il le voit : il va vers sa position réelle
		perduDepuis = nil
		perception.prendreBruit() -- inutile : il le voit
		local cibleP = memoire.dernierePosition or terrain.auSol(r.Position)
		piste = cibleP
		regard = cibleP + Vector3.new(0, 3, 0)
		local ecart = cibleP - racine.Position
		if Vector3.new(ecart.X, 0, ecart.Z).Magnitude < R.DISTANCE_DIRECTE
			and terrain.zoneDe(cibleP) == terrain.zoneDe(racine.Position) then
			deplacement.foncer(cibleP) -- tout près : droit sur lui, sans calcul de chemin
		else
			local fini = deplacement.estFini()
			local but = deplacement.but()
			if maintenant - dernierCalcul > R.PERIODE_RECALCUL
				and (fini or not but or (cibleP - but).Magnitude > R.DEPLACEMENT_RECALCUL) then
				dernierCalcul = maintenant
				if not deplacement.calculer(cibleP)
					and (fini or terrain.zoneDe(cibleP) == terrain.zoneDe(racine.Position)) then
					deplacement.direct(cibleP) -- calcul raté : il fonce droit au lieu de s'arrêter
				end
			end
			deplacement.suivre()
		end
		return
	end

	-- il ne le voit plus : il va là où il pense le trouver, sans tricher
	regard = nil
	if not memoire.dernierePosition then
		changerEtat("patrouille") -- aucune idée d'où il est (ne devrait pas arriver)
		return
	end
	if not perduDepuis then
		perduDepuis = maintenant
		local v = memoire.derniereVitesse
		local estimee = terrain.auSol(memoire.dernierePosition + Vector3.new(v.X, 0, v.Z) * R.ANTICIPATION)
		piste = estimee
		if not deplacement.calculer(estimee) and not deplacement.calculer(memoire.dernierePosition) then
			deplacement.direct(memoire.dernierePosition)
		end
	end
	-- le joueur fait du bruit en fuyant : il suit le bruit (et prolonge la traque)
	local bruit = perception.prendreBruit()
	if bruit then
		perduDepuis = maintenant
		piste = bruit.estime
		if not deplacement.calculer(bruit.estime) and not deplacement.calculer(bruit.brut) then
			deplacement.direct(bruit.brut)
		end
	end
	if (not deplacement.suivre() and dansEtat > 0.4) or maintenant - perduDepuis > R.TEMPS_POURSUITE_AVEUGLE then
		memoire.finPoursuite = maintenant
		commencerRecherche(piste or memoire.dernierePosition, memoire.derniereVitesse)
	end
end

function MAJ.recherche(maintenant, dansEtat)
	if dansEtat > R.DUREE_RECHERCHE_MAX then
		changerEtat("patrouille")
		return
	end
	if recherche.phase == "regard" then
		-- il tourne le corps à gauche puis à droite
		local t = maintenant - recherche.debutPhase
		deplacement.orienter(recherche.lacetBase + math.sin(t * 1.6) * math.rad(70), 0.25)
		if t >= R.DUREE_REGARD then
			deplacement.repartir()
			recherche.index += 1
			local but = recherche.buts[recherche.index]
			if not but then
				changerEtat("patrouille")
			elseif deplacement.calculer(but) then
				recherche.phase = "marche"
			else
				recherche.debutPhase = maintenant -- point inaccessible : il regarde encore, puis passe au suivant
				humanoid.AutoRotate = false
			end
		end
	elseif not deplacement.suivre() then
		recherche.phase = "regard"
		recherche.debutPhase = maintenant
		recherche.lacetBase = deplacement.lacetDe(racine.CFrame.LookVector)
		deplacement.arreter()
	end
end

function MAJ.attaque(_maintenant, dansEtat)
	if attaque.position then
		deplacement.faireFace(attaque.position, 0.5)
		regard = attaque.position + Vector3.new(0, 2, 0)
	end
	if dansEtat >= R.DUREE_ATTAQUE then
		-- il lâche sa proie et part patrouiller loin d'elle
		memoire.cible = nil
		memoire.voitCible = false
		memoire.finPoursuite = -math.huge
		loinDe = attaque.position
		attaque.position = nil
		changerEtat("patrouille")
	end
end

local function decider(maintenant)
	local def = ETATS[etat]

	if etat ~= "attente" then
		-- 1. il vient d'attraper quelqu'un (priorité sur tout)
		local prise = table.remove(contactsEnAttente, 1)
		if prise and etat ~= "attaque" then
			table.clear(contactsEnAttente) -- une prise à la fois ; les autres joueurs sont déjà en répit
			changerEtat("attaque")
			attaque.position = prise.position
			return
		end

		-- 2. il voit un joueur
		if memoire.voitCible and not def.chasse then
			if maintenant - memoire.finPoursuite < R.REPRISE_SANS_ALERTE then
				changerEtat("poursuite") -- il vient de le perdre : il reprend tout de suite
			else
				changerEtat("alerte")
			end
			return
		end

		-- 3. il entrevoit quelqu'un
		if def.calme and memoire.indiceVu and memoire.soupcon >= R.SEUIL_SOUPCON
			and maintenant - finSoupcon > R.PAUSE_ENTRE_SOUPCONS then
			changerEtat("soupcon")
			return
		end

		-- 4. il entend un bruit
		if def.calme then
			local bruit = perception.prendreBruit()
			if bruit then
				if etat == "ecoute" then
					-- il écoute encore : il retient le bruit le plus récent, le temps d'écoute ne repart pas
					ecoute.estime, ecoute.brut, ecoute.source = bruit.estime, bruit.brut, bruit.source
					prevenir(bruit.source)
				elseif etat == "enquete" then
					-- même endroit (le balai refait du bruit toutes les 1,2 s) : il continue vers son but ;
					-- autre endroit : il change de but sans s'arrêter
					if (bruit.brut - enquete.brut).Magnitude > R.ECART_NOUVEAU_BRUIT then
						commencerEnquete(bruit.estime, bruit.brut, bruit.source)
						return
					end
				elseif etat == "recherche" and dernierBruitSuivi.brut
					and maintenant - dernierBruitSuivi.instant < R.DUREE_RECHERCHE_MAX
					and (bruit.brut - dernierBruitSuivi.brut).Magnitude <= R.ECART_NOUVEAU_BRUIT
					and (bruit.brut - terrain.auSol(racine.Position)).Magnitude <= R.DISTANCE_SUR_PLACE then
					-- il fouille déjà cet endroit et il est encore tout près : le même bruit (le balai en refait
					-- toutes les 1,2 s) ne le fait pas se remettre à écouter. Pas de va-et-vient, pas de nouvel
					-- avertissement ; tant que le bruit dure, il garde sa recherche active.
					dernierBruitSuivi.instant = maintenant
					debutEtat = maintenant
				else
					commencerEcoute(bruit) -- patrouille, ou recherche ailleurs : il s'arrête pour écouter
					return
				end
			end
		end
	end

	MAJ[etat](maintenant, maintenant - debutEtat)
end

---------------------------------------------------------------------------
-- Attributs pour le client et débogage
---------------------------------------------------------------------------

local function publierAttributs()
	local cibleId = 0
	if (etat == "alerte" or etat == "poursuite") and memoire.cible then
		cibleId = memoire.cible.UserId
	end
	definirAttribut("CibleId", cibleId)
	-- le regard n'est renvoyé que s'il a bougé de plus de 1,5 stud (moins de trafic réseau)
	local actuel = monstre:GetAttribute("Regard")
	if regard == nil then
		definirAttribut("Regard", nil)
	elseif typeof(actuel) ~= "Vector3" or (actuel - regard).Magnitude > 1.5 then
		monstre:SetAttribute("Regard", regard)
	end
end

local etiquetteDebug = nil
if R.DEBUG then
	local panneau = Instance.new("BillboardGui")
	panneau.Name = "DebugEtat"
	panneau.Size = UDim2.fromOffset(220, 40)
	panneau.StudsOffset = Vector3.new(0, 4, 0)
	panneau.AlwaysOnTop = true
	etiquetteDebug = Instance.new("TextLabel")
	etiquetteDebug.Size = UDim2.fromScale(1, 1)
	etiquetteDebug.BackgroundTransparency = 0.4
	etiquetteDebug.BackgroundColor3 = Color3.new(0, 0, 0)
	etiquetteDebug.TextColor3 = Color3.new(1, 1, 1)
	etiquetteDebug.TextScaled = true
	etiquetteDebug.Parent = panneau
	panneau.Adornee = tete or racine
	panneau.Parent = monstre
end

local function afficherDebug()
	if etiquetteDebug then
		local vigilanceMax = 0
		for _, joueur in Players:GetPlayers() do
			vigilanceMax = math.max(vigilanceMax, perception.vigilanceDe(joueur))
		end
		etiquetteDebug.Text = ("%s  vigilance %.2f"):format(etat, vigilanceMax)
	end
end

---------------------------------------------------------------------------
-- Boucle principale : perception ~6 fois par seconde, décision et marche 20 fois par seconde
---------------------------------------------------------------------------

changerEtat("attente")
local derniereVision = os.clock()
while true do
	local maintenant = os.clock()
	if etat == "attente" then
		derniereVision = maintenant
	elseif maintenant - derniereVision >= R.PERIODE_VISION then
		-- dt plafonné : un calcul de chemin long ne doit pas remplir la vigilance d'un coup
		local dt = math.min(maintenant - derniereVision, 0.5)
		perception.percevoir(dt, maintenant, ETATS[etat].chasse == true)
		derniereVision = maintenant
	end
	decider(maintenant)
	publierAttributs()
	afficherDebug()
	task.wait(R.PERIODE_DECISION)
end
