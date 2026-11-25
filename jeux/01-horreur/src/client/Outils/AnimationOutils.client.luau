--!strict
--[[
	Rôle    : fait bouger le haut du corps du joueur local quand il utilise un outil (coup de
	          balai à deux mains, va-et-vient de l'aspirateur), en version sol ou mur selon
	          l'attribut TypeCible posé par le serveur sur l'outil.
	          - le serveur pose l'attribut « EnUtilisation » sur le Tool : il décide seul ;
	          - ici on joue (ou on arrête) une animation générée à l'exécution à partir de
	            FormesAnimation, sur l'Animator du personnage local.
	          Les animations jouées par le propriétaire du personnage sont répliquées par Roblox :
	          les autres joueurs voient donc aussi le mouvement, sans code supplémentaire.
	          Pourquoi pas C0 / Transform : sur les rigs modernes l'épaule est un
	          AnimationConstraint dont C0 est en lecture seule, et l'Animator reprend la main
	          sur Transform. Une vraie animation est la seule voie qui fonctionne (testé).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24 (corps entier, sol / mur : 2026-11-25)
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Definitions = require(Partage:WaitForChild("DefinitionsOutils") :: ModuleScript)
local Formes = require(script.Parent:WaitForChild("FormesAnimation") :: ModuleScript)

local Reglages = Definitions.Reglages

local FONDU_ENTREE = 0.15
local FONDU_SORTIE = 0.2

type Forme = Formes.Forme

local joueur = Players.LocalPlayer

-- ===== Fabrication de l'animation =====

local idsEnregistres: { [string]: string } = {} -- nom de forme -> contenu enregistré

-- Une Pose par os, de la racine à la main : les os sans mouvement ont un poids de 0.
local function creerPose(nom: string, parent: Instance, poids: number, cframe: CFrame?): Pose
	local pose = Instance.new("Pose")
	pose.Name = nom
	pose.Weight = poids
	pose.EasingStyle = Enum.PoseEasingStyle.Cubic
	pose.EasingDirection = Enum.PoseEasingDirection.InOut
	if cframe then
		pose.CFrame = cframe
	end
	pose.Parent = parent
	return pose
end

local function construireSequence(forme: Forme): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = "AnimationOutil"
	sequence.Loop = true
	sequence.Priority = Enum.AnimationPriority.Action -- passe devant la pose « outil en main »
	for _, cle in forme.cles do
		local image = Instance.new("Keyframe")
		image.Time = cle.temps
		local racine = creerPose("HumanoidRootPart", image, 0, nil)
		local bassin = creerPose("LowerTorso", racine, 0, nil)
		-- Les jambes ne sont pas dans la séquence : la marche continue de les animer
		local torse = creerPose("UpperTorso", bassin, 1, cle.taille)
		local brasD = creerPose("RightUpperArm", torse, 1, cle.epauleD)
		creerPose("RightLowerArm", brasD, 1, cle.coudeD)
		local brasG = creerPose("LeftUpperArm", torse, 1, cle.epauleG)
		creerPose("LeftLowerArm", brasG, 1, cle.coudeG)
		creerPose("Head", torse, 1, cle.cou)
		image.Parent = sequence
	end
	return sequence
end

-- Enregistre la forme une seule fois ; nil si l'enregistrement échoue
local function idPourForme(nomForme: string): string?
	local connu = idsEnregistres[nomForme]
	if connu then
		return connu
	end
	local forme = Formes[nomForme]
	if not forme then
		return nil
	end
	local sequence = construireSequence(forme)
	local ok, resultat = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	sequence:Destroy()
	if not ok then
		warn("AnimationOutils : enregistrement impossible pour " .. nomForme .. " : " .. tostring(resultat))
		return nil
	end
	idsEnregistres[nomForme] = resultat
	return resultat
end

-- ===== Suivi du personnage et de l'outil =====

local pistes: { [string]: AnimationTrack } = {}  -- pistes chargées sur l'Animator courant
local pisteActive: AnimationTrack? = nil
local outilSuivi: Tool? = nil
local connexionsOutil: { RBXScriptConnection } = {}
local connexionsPerso: { RBXScriptConnection } = {}
local personnageCourant: Model? = nil

local function deconnecter(liste: { RBXScriptConnection })
	for _, c in liste do
		c:Disconnect()
	end
	table.clear(liste)
end

local function arreterPiste()
	if pisteActive then
		pisteActive:Stop(FONDU_SORTIE)
		pisteActive = nil
	end
end

local function obtenirPiste(nomForme: string): AnimationTrack?
	local existante = pistes[nomForme]
	if existante then
		return existante
	end
	local personnage = personnageCourant
	local humanoide = if personnage then personnage:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoide then humanoide:FindFirstChildOfClass("Animator") else nil
	if not animator then
		return nil
	end
	local id = idPourForme(nomForme)
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, piste = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		warn("AnimationOutils : LoadAnimation a échoué : " .. tostring(piste))
		return nil
	end
	piste.Priority = Enum.AnimationPriority.Action
	piste.Looped = true
	pistes[nomForme] = piste
	return piste
end

-- Joue ou arrête selon l'attribut posé par le serveur
local function mettreAJour()
	local tool = outilSuivi
	if not tool or tool.Parent ~= personnageCourant then
		arreterPiste()
		return
	end
	local definition = Definitions.obtenir(tool:GetAttribute(Reglages.ATTRIBUT_OUTIL))
	local actif = tool:GetAttribute(Reglages.ATTRIBUT_EN_UTILISATION) == true
	if not (actif and definition) then
		arreterPiste()
		return
	end
	-- Tache murale (le serveur pose TypeCible sur l'outil) : version « Mur » si elle existe
	local nomForme = definition.animation
	if tool:GetAttribute(Reglages.ATTRIBUT_TYPE_CIBLE) == "Mur" and Formes[nomForme .. "Mur"] then
		nomForme ..= "Mur"
	end
	local piste = obtenirPiste(nomForme)
	if not piste then
		return
	end
	if pisteActive ~= piste then
		arreterPiste()
		piste:Play(FONDU_ENTREE)
		pisteActive = piste
	end
end

local function oublierOutil()
	arreterPiste()
	deconnecter(connexionsOutil)
	outilSuivi = nil
end

local function suivreOutil(tool: Tool)
	if tool == outilSuivi then
		return
	end
	oublierOutil()
	outilSuivi = tool
	table.insert(connexionsOutil, tool:GetAttributeChangedSignal(Reglages.ATTRIBUT_EN_UTILISATION):Connect(mettreAJour))
	table.insert(connexionsOutil, tool:GetAttributeChangedSignal(Reglages.ATTRIBUT_TYPE_CIBLE):Connect(mettreAJour))
	mettreAJour()
end

local function lierPersonnage(personnage: Model)
	if joueur.Character ~= personnage or personnageCourant == personnage then
		return
	end
	oublierOutil()
	deconnecter(connexionsPerso)
	table.clear(pistes) -- les pistes appartiennent à l'ancien Animator
	personnageCourant = personnage

	table.insert(connexionsPerso, personnage.ChildAdded:Connect(function(enfant: Instance)
		if enfant:IsA("Tool") then
			suivreOutil(enfant)
		end
	end))
	table.insert(connexionsPerso, personnage.ChildRemoved:Connect(function(enfant: Instance)
		if enfant == outilSuivi then
			oublierOutil()
		end
	end))
	local deja = personnage:FindFirstChildOfClass("Tool")
	if deja then
		suivreOutil(deja)
	end
end

joueur.CharacterRemoving:Connect(function(personnage: Model)
	if personnageCourant == personnage then
		oublierOutil()
		deconnecter(connexionsPerso)
		table.clear(pistes)
		personnageCourant = nil
	end
end)
joueur.CharacterAdded:Connect(lierPersonnage)
if joueur.Character then
	task.defer(lierPersonnage, joueur.Character)
end
