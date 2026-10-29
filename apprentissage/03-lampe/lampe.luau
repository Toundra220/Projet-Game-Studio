--[[
	Rôle    : exercice 3
	Origine : ÉCRIT par moi
	Auteur  : Romain Lesur
	Date    : 2026-10-29
	Notions : PointLight, Enabled, while, task.wait
]]


local lumiere = workspace.Lampe.PointLight

while true do
	lumiere.Enabled = true
	task.wait(1)
	print("Lampe allumée")
	lumiere.Enabled = false
	task.wait(1) 
	print("Lampe éteinte")
end