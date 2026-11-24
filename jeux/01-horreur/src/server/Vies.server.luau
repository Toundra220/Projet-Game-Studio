--[[
	Rôle    : vies des joueurs (conception : 3 vies ; attrapé = une vie perdue, on reprend sur place ;
	          0 vie = la partie recommence).
	          Écoute MonstreContact (émis par MonstreIA, côté serveur uniquement).
	          Attributs du joueur (lus par le client RetourMonstre) :
	            Vies (nombre)            : vies restantes
	            Invulnerable (booléen)   : vrai pendant INVULNERABILITE secondes après une prise
	          À 0 vie : émet ServerStorage.PartieEchoueeEvent(joueur), remet 3 vies et fait
	          réapparaître le joueur au point de départ (le reste du « tout recommencer »,
	          comme les tâches, sera branché quand le gestionnaire de tâches existera).
	          Contrat repris du script désactivé ServerScriptService.MonstreIA_Complet.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VIES_DEPART = 3
local INVULNERABILITE = 4          -- secondes d'immunité après une prise
local DELAI_REAPPARITION = 1.5     -- secondes entre la dernière vie perdue et la réapparition

local function trouverOuCreer(parent: Instance, nom: string): BindableEvent
	local existant = parent:FindFirstChild(nom)
	if existant and existant:IsA("BindableEvent") then
		return existant
	end
	local evenement = Instance.new("BindableEvent")
	evenement.Name = nom
	evenement.Parent = parent
	return evenement
end

local contact = trouverOuCreer(ReplicatedStorage, "MonstreContact")
local partieEchouee = trouverOuCreer(ServerStorage, "PartieEchoueeEvent")

local invulnerableJusqua: { [Player]: number } = {}

local function initialiser(joueur: Player)
	joueur:SetAttribute("Vies", VIES_DEPART)
	joueur:SetAttribute("Invulnerable", false)
end

Players.PlayerAdded:Connect(initialiser)
for _, joueur in Players:GetPlayers() do
	initialiser(joueur)
end

Players.PlayerRemoving:Connect(function(joueur)
	invulnerableJusqua[joueur] = nil
end)

contact.Event:Connect(function(joueur)
	-- BindableEvent serveur : seul MonstreIA l'émet, mais on vérifie quand même ce qu'on reçoit
	if typeof(joueur) ~= "Instance" or not joueur:IsA("Player") or joueur.Parent ~= Players then
		return
	end
	local maintenant = os.clock()
	if (invulnerableJusqua[joueur] or 0) > maintenant then
		return
	end
	invulnerableJusqua[joueur] = maintenant + INVULNERABILITE
	joueur:SetAttribute("Invulnerable", true)

	local vies = joueur:GetAttribute("Vies")
	if type(vies) ~= "number" then
		vies = VIES_DEPART
	end
	vies = math.max(0, vies - 1)
	joueur:SetAttribute("Vies", vies)

	task.delay(INVULNERABILITE, function()
		if joueur.Parent == Players and (invulnerableJusqua[joueur] or 0) <= os.clock() then
			joueur:SetAttribute("Invulnerable", false)
		end
	end)

	if vies <= 0 then
		partieEchouee:Fire(joueur)
		task.delay(DELAI_REAPPARITION, function()
			if joueur.Parent ~= Players then
				return
			end
			joueur:SetAttribute("Vies", VIES_DEPART)
			local ok = pcall(function()
				joueur:LoadCharacterAsync()
			end)
			if not ok then
				pcall(function()
					joueur:LoadCharacter() -- ancien nom, si LoadCharacterAsync n'est pas disponible
				end)
			end
		end)
	end
end)
