--!strict
--[[
	Rôle    : affiche le niveau de bruit du joueur (IndicateurBruit, en bas à droite).
	          Le client ne calcule rien et n'envoie rien : il lit l'attribut NiveauBruit de son
	          Player, écrit par le serveur (Server/Bruit/ServiceBruit), et le montre.
	          Mise à jour seulement quand l'attribut change (pas de lecture à chaque image).
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReglagesBruit = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bruit"):WaitForChild("ReglagesBruit"))
local IndicateurBruit = require(script.Parent:WaitForChild("IndicateurBruit"))

local joueur = Players.LocalPlayer
local indicateur = IndicateurBruit.nouveau(ReglagesBruit, joueur:WaitForChild("PlayerGui"))

local function lire()
	local niveau = joueur:GetAttribute(ReglagesBruit.ATTRIBUT_NIVEAU)
	indicateur.afficher(if type(niveau) == "number" then niveau else 0)
end

joueur:GetAttributeChangedSignal(ReglagesBruit.ATTRIBUT_NIVEAU):Connect(lire)
lire() -- les signaux ne rejouent pas la valeur déjà présente
