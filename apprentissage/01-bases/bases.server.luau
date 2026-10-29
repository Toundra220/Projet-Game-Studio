--[[
	Rôle    : exercice 1, variables, fonctions et print
	Origine : ÉCRIT par moi, erreurs corrigées avec Claude
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