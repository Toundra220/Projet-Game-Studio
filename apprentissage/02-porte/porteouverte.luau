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
