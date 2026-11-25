--!strict
--[[
	Rôle    : racine de composition du sprint côté joueur. Le client ne décide rien :
	          - il envoie « je veux courir / j'arrête » au serveur (RemoteSprint) ;
	          - il lit l'endurance et l'état de course sur son Player (attributs écrits par le serveur,
	            voir Server/Sprint/ServiceSprint) et les montre : jauge (JaugeEndurance) et léger
	            élargissement du champ de vision (EffetCourse).
	          Entrée : Shift / L3 / bouton tactile (EntreeCourse). Chiffres : Shared/Sprint/ReglagesSprint.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sprint"):WaitForChild("ReglagesSprint"))
local RemoteSprint = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sprint"):WaitForChild("RemoteSprint"))
local EntreeCourse = require(script.Parent:WaitForChild("EntreeCourse"))
local JaugeEndurance = require(script.Parent:WaitForChild("JaugeEndurance"))
local EffetCourse = require(script.Parent:WaitForChild("EffetCourse"))

local joueur = Players.LocalPlayer
local remote = RemoteSprint.obtenir()

local jauge = JaugeEndurance.nouveau(Reglages)
local effet = EffetCourse.nouveau(Reglages)

local entree = EntreeCourse.demarrer(Reglages, function(veutCourir: boolean)
	remote:FireServer(veutCourir)
	-- il demande à courir alors que la jauge est vide : la barre le signale
	if veutCourir and joueur:GetAttribute(Reglages.ATTRIBUT_EPUISE) == true then
		jauge.signaler(0.6)
	end
end)

-- valeurs du serveur (absentes un court instant au démarrage : jauge pleine par défaut)
local endurance, epuise, court = 1, false, false

local function lireAttributs()
	local e = joueur:GetAttribute(Reglages.ATTRIBUT_ENDURANCE)
	endurance = if type(e) == "number" then math.clamp(e, 0, 1) else 1
	local vide = joueur:GetAttribute(Reglages.ATTRIBUT_EPUISE) == true
	if vide and not epuise then
		jauge.signaler(1.2) -- la jauge vient de se vider
		entree.relacher()   -- bouton tactile à bascule : la course ne reprend pas toute seule
	end
	epuise = vide
	court = joueur:GetAttribute(Reglages.ATTRIBUT_COURT) == true
end

for _, nom in { Reglages.ATTRIBUT_ENDURANCE, Reglages.ATTRIBUT_EPUISE, Reglages.ATTRIBUT_COURT } do
	joueur:GetAttributeChangedSignal(nom):Connect(lireAttributs)
end
lireAttributs()

-- nouveau personnage : le serveur a remis l'état à zéro, on lâche la demande locale
joueur.CharacterAdded:Connect(function()
	entree.relacher()
end)

RunService.RenderStepped:Connect(function(dt)
	jauge.mettreAJour(dt, endurance, epuise, court)
	effet.mettreAJour(dt, court)
end)
