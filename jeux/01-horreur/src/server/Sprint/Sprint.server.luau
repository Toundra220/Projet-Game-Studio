--!strict
--[[
	Rôle    : racine de composition du sprint côté serveur : choisit les implémentations et les
	          branche (réglages, remote, limiteur de débit). Toute la logique est dans
	          Sprint/ServiceSprint et Sprint/Endurance ; les chiffres dans Shared/Sprint/ReglagesSprint.
	          Le limiteur de débit est celui des outils (Outils/LimiteDebit), réutilisé sans modification.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sprint")
local Reglages = require(partage:WaitForChild("ReglagesSprint"))
local RemoteSprint = require(partage:WaitForChild("RemoteSprint"))

-- Server/Sprint/Sprint -> Server/Outils/LimiteDebit
local LimiteDebit = require(script.Parent.Parent:WaitForChild("Outils"):WaitForChild("LimiteDebit"))
local ServiceSprint = require(script.Parent:WaitForChild("ServiceSprint"))

ServiceSprint.demarrer({
	reglages = Reglages,
	remote = RemoteSprint.obtenir(),
	limiteur = LimiteDebit.nouveau(Reglages.LIMITE_CAPACITE, Reglages.LIMITE_RECHARGE),
})
