--[[
	Rôle    : connaissance du lieu pour le monstre : hauteur du sol, étage d'une position
	          (rdc, etage ou escalier) et axe de l'escalier.
	          Escalier : deux repères invisibles dans le Workspace, EscalierBas (pied, rez-de-chaussée)
	          et EscalierHaut (sommet, étage), et les marches Manoir.RezDeChaussee.Escalier.MarcheN.
	          Sans eux, tout est considéré comme le rez-de-chaussée.
	Origine : ÉCRIT PAR CLAUDE (extrait de MonstreIA.server.luau)
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Players = game:GetService("Players")

local Terrain = {}

function Terrain.nouveau(exclusFixes: { Instance })
	local self = {}

	-- Rayons vers le sol : on ignore le monstre, les repères et les joueurs,
	-- et les pièces qu'on peut traverser (CanCollide false : décor, saletés au sol).
	local paramsSol = RaycastParams.new()
	paramsSol.FilterType = Enum.RaycastFilterType.Exclude
	paramsSol.IgnoreWater = true
	paramsSol.RespectCanCollide = true

	-- La liste des personnages change rarement : on la reconstruit au plus une fois par seconde
	-- (avant, une liste neuve était créée à chaque rayon).
	local filtreMisAJour = -math.huge
	local function mettreAJourFiltre()
		local maintenant = os.clock()
		if maintenant - filtreMisAJour < 1 then
			return
		end
		filtreMisAJour = maintenant
		local exclus = table.clone(exclusFixes)
		for _, joueur in Players:GetPlayers() do
			if joueur.Character then
				table.insert(exclus, joueur.Character)
			end
		end
		paramsSol.FilterDescendantsInstances = exclus
	end

	function self.hauteurSol(pos: Vector3): number
		mettreAJourFiltre()
		local resultat = workspace:Raycast(pos, Vector3.new(0, -60, 0), paramsSol)
		return resultat and resultat.Position.Y or pos.Y - 4
	end

	-- Même position ramenée au sol (un joueur qui saute est en l'air : pas de chemin possible vers lui)
	function self.auSol(pos: Vector3): Vector3
		return Vector3.new(pos.X, self.hauteurSol(pos) + 0.5, pos.Z)
	end

	-- Escalier
	local bas = workspace:FindFirstChild("EscalierBas")
	local haut = workspace:FindFirstChild("EscalierHaut")
	local seuilEtage, zone = nil, nil
	if bas and haut and bas:IsA("BasePart") and haut:IsA("BasePart") then
		seuilEtage = (bas.Position.Y + haut.Position.Y) / 2
		local manoir = workspace:FindFirstChild("Manoir")
		local rdc = manoir and manoir:FindFirstChild("RezDeChaussee")
		local escalier = rdc and rdc:FindFirstChild("Escalier")
		if escalier then
			local xmin, xmax, zmin, zmax = math.huge, -math.huge, math.huge, -math.huge
			for _, p in escalier:GetChildren() do
				if p:IsA("BasePart") and p.Name:match("^Marche%d+$") then
					xmin = math.min(xmin, p.Position.X - p.Size.X / 2)
					xmax = math.max(xmax, p.Position.X + p.Size.X / 2)
					zmin = math.min(zmin, p.Position.Z - p.Size.Z / 2)
					zmax = math.max(zmax, p.Position.Z + p.Size.Z / 2)
				end
			end
			if xmin < xmax then
				zone = { xmin = xmin, xmax = xmax, zmin = zmin, zmax = zmax }
			end
		end
	end
	if not (seuilEtage and zone) then
		warn("MonstreIA : repères EscalierBas / EscalierHaut ou marches absents, le monstre ne changera pas d'étage")
		seuilEtage, zone, bas, haut = nil, nil, nil, nil
	end
	self.escalierBas = bas
	self.escalierHaut = haut

	-- "rdc", "etage" ou "escalier" (sur les marches)
	function self.zoneDe(pos: Vector3): string
		if not seuilEtage then
			return "rdc"
		end
		local h = self.hauteurSol(pos)
		local solRdc = bas.Position.Y - 0.5 -- les repères sont à 0,5 stud au dessus du sol
		local solEtage = haut.Position.Y - 0.5
		local dansRectangle = pos.X > zone.xmin - 1 and pos.X < zone.xmax + 1
			and pos.Z > zone.zmin - 1 and pos.Z < zone.zmax + 1
		if dansRectangle and h > solRdc + 0.4 and h < solEtage - 0.4 then
			return "escalier"
		end
		return h > seuilEtage and "etage" or "rdc"
	end

	-- Position le long de l'escalier : 0 = pied, 1 = sommet
	function self.parametreEscalier(pos: Vector3): number
		local axe = haut.Position - bas.Position
		local axeH = Vector3.new(axe.X, 0, axe.Z)
		local rel = Vector3.new(pos.X - bas.Position.X, 0, pos.Z - bas.Position.Z)
		return math.clamp(rel:Dot(axeH) / axeH:Dot(axeH), 0, 1)
	end

	-- Point de l'axe de l'escalier à la hauteur de « pos »
	function self.pointEscalier(pos: Vector3): Vector3
		return bas.Position:Lerp(haut.Position, self.parametreEscalier(pos))
	end

	return self
end

return Terrain
