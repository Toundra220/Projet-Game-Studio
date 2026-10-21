--[[
	Rôle    : exercice 1, variables, fonctions et print
	Origine : ÉCRIT  (remplacer par ADAPTÉ de <source> ou RÉUTILISÉ de <source> si besoin)
	Auteur  : Romain Lesur
	Date    : 2026-10-
	Notions : variables locales, fonctions, conditions
]]

local function saluer(nom: string): string
	return "Bonjour " .. nom
end

print(saluer("Studio"))

local function additionner(a, b): number
	return (a + b) 
end 

print(additionner(1, 2))