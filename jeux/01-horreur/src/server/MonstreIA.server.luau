--[[
	Rôle    : IA du monstre du jeu 1 (horreur). Patrouille entre des points du couloir,
	          poursuit le joueur qu'il voit, continue de le suivre quelques secondes
	          après l'avoir perdu de vue, et joue les animations de marche et de course.
	          Émet MonstreContact (BindableEvent) au contact.
	Origine : ÉCRIT (ébauche à relire et adapter)
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
local VITESSE_POURSUITE = 17
local TEMPS_PERDU = 8            -- secondes qu'il continue de suivre le joueur après l'avoir perdu de vue
local DELAI_CONTACT = 2          -- secondes entre deux contacts avec le même joueur

-- Points de patrouille (couloir du rez-de-chaussée)
local POINTS = {
	Vector3.new(30, 0, 72),
	Vector3.new(100, 0, 72),
	Vector3.new(200, 0, 72),
}

local monstre = workspace:WaitForChild("MonstreRodin")
local humanoid = monstre:FindFirstChildOfClass("Humanoid")
local racine = monstre:FindFirstChild("HumanoidRootPart")
assert(humanoid and racine, "MonstreRodin doit avoir un Humanoid et un HumanoidRootPart")
monstre.PrimaryPart = racine

-- Animations : le serveur dit l'allure (marche ou course) dans l'attribut « Allure »,
-- le LocalScript AnimationMonstre fait bouger le squelette chez chaque joueur.
racine:SetNetworkOwner(nil)
local function jouer(allure)
	monstre:SetAttribute("Allure", allure)
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

-- Calcule le chemin et avance jusqu'au deuxième point (le premier est la position actuelle).
local function avancerVers(but, duree)
	local chemin = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 12, AgentCanJump = false })
	local ok = pcall(function() chemin:ComputeAsync(racine.Position, but) end)
	if not ok or chemin.Status ~= Enum.PathStatus.Success then
		return false
	end
	local wps = chemin:GetWaypoints()
	local prochain = wps[2]
	if not prochain then
		return true
	end
	if prochain.Action == Enum.PathWaypointAction.Jump then
		humanoid.Jump = true
	end
	humanoid:MoveTo(prochain.Position)
	local fini = false
	local connexion = humanoid.MoveToFinished:Connect(function() fini = true end)
	local debut = os.clock()
	while not fini and os.clock() - debut < duree do
		task.wait(0.1)
	end
	connexion:Disconnect()
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

-- Boucle principale : patrouille, poursuite, suivi après perte de vue
local etat = "patrouille"
local index = 1
local dernierVu = 0
local cible = nil

while true do
	local vu = joueurVu()
	if vu then
		etat = "poursuite"
		cible = vu
		dernierVu = os.clock()
	end

	if etat == "poursuite" and cible and cible:FindFirstChild("HumanoidRootPart") and os.clock() - dernierVu < TEMPS_PERDU then
		-- il voit le joueur, ou il le suit encore pendant TEMPS_PERDU secondes
		humanoid.WalkSpeed = VITESSE_POURSUITE
		jouer("course")
		avancerVers(cible.HumanoidRootPart.Position, 1.5)
	else
		etat = "patrouille"
		cible = nil
		humanoid.WalkSpeed = VITESSE_PATROUILLE
		jouer("marche")
		local but = POINTS[index]
		avancerVers(but, 4)
		local ecart = racine.Position - but
		if Vector3.new(ecart.X, 0, ecart.Z).Magnitude < 5 then -- on ignore la hauteur
			index = index % #POINTS + 1
		end
	end
	task.wait(0.1)
end
