--!strict
--[[
	Rôle    : prévient le joueur quand le monstre vient voir le bruit qu'il fait en nettoyant
	          (équivalent visuel d'un bruit : un message en bas de l'écran, voir Notification).
	          Le serveur (MonstreIA) pose l'attribut booléen « MonstreAttire » sur le Player tant
	          que le monstre approche à cause de CE joueur ; ce script ne décide rien, il affiche.
	          Le message ne revient pas à chaque bruit : seulement quand l'attribut passe à vrai.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReglagesTaches = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Taches"):WaitForChild("ReglagesTaches"))
-- Client/Taches/AvertissementBruit -> Client/Outils/Notification
local Notification = require(script.Parent.Parent:WaitForChild("Outils"):WaitForChild("Notification"))

local joueur = Players.LocalPlayer
local ATTRIBUT = ReglagesTaches.ATTRIBUT_AVERTISSEMENT

local function surChangement()
	if joueur:GetAttribute(ATTRIBUT) == true then
		Notification.afficher(ReglagesTaches.MESSAGE_AVERTISSEMENT, ReglagesTaches.DUREE_MESSAGE)
	end
end

joueur:GetAttributeChangedSignal(ATTRIBUT):Connect(surChangement)
surChangement()
