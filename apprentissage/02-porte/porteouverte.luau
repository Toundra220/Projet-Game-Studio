--[[
	Rôle    : exercice 2, variables, fonctions et print
	Origine : ÉCRIT  
	Auteur  : Romain Lesur
	Date    : 2026-10-29
	Notions : Connection à Studio, interration, comprehension de l'environnement
]]


local porte = workspace.Porte
local ouverte = false

porte.Touched:Connect(function(partTouchee)
	if ouverte == false then
		ouverte = true
		porte.Transparency = 1
		porte.CanCollide = false
		task.wait(3)
		porte.Transparency = 0
		porte.CanCollide = true
		ouverte = false
		print("Porte ouverte")
	end
end)
