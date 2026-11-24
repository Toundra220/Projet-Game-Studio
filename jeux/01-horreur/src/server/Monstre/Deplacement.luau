--[[
	Rôle    : déplacement du monstre : calcul du chemin (PathfindingService), passage par
	          l'escalier en ligne droite (marches trop hautes pour le calcul habituel), suivi
	          continu des points, et anti-blocage :
	            - chemin coupé par un obstacle (Path.Blocked) : recalcul
	            - il n'avance plus pendant DELAI_BLOCAGE : il recule en biais, puis recalcule ;
	              au deuxième blocage de suite il abandonne ce but (l'état en choisit un autre)
	            - plusieurs calculs ratés de suite : courte pause des calculs
	          Ne décide rien : les états lui disent où aller.
	Origine : ÉCRIT PAR CLAUDE (extrait et complété de MonstreIA.server.luau)
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local PathfindingService = game:GetService("PathfindingService")

local Deplacement = {}

-- ctx = { reglages, humanoid, racine, terrain }
function Deplacement.nouveau(ctx)
	local R = ctx.reglages
	local humanoid: Humanoid = ctx.humanoid
	local racine: BasePart = ctx.racine
	local terrain = ctx.terrain
	local aleatoire = Random.new()
	local ACTION_MARCHE = Enum.PathWaypointAction.Walk

	local self = {}

	local points = {}        -- points du chemin en cours : { Position = ..., Action = ... }
	local indexPoint = 1     -- prochain point à atteindre
	local butActuel = nil    -- destination du chemin en cours (pour le recalculer)
	local connexionsBlocage = {}
	local cheminCoupe = false

	-- surveillance du blocage : progrès vers le point visé, et déplacement réel du corps
	local suiviIndex, suiviDistance, suiviDepuis = nil, 0, 0
	local ancrePosition, ancreDepuis = nil, 0
	local blocages = 0
	local reculJusqua, pointRecul = 0, nil

	local echecsDeSuite = 0
	local pauseCalculsJusqua = 0

	-- Débogage : points du chemin dessinés dans Workspace.DebugMonstre
	local dossierDebug = nil
	local function dessiner()
		if not R.DEBUG then
			return
		end
		if not dossierDebug then
			dossierDebug = Instance.new("Folder")
			dossierDebug.Name = "DebugMonstre"
			dossierDebug.Parent = workspace
		end
		dossierDebug:ClearAllChildren()
		for i, p in points do
			local boule = Instance.new("Part")
			boule.Shape = Enum.PartType.Ball
			boule.Size = Vector3.new(0.8, 0.8, 0.8)
			boule.Anchored = true
			boule.CanCollide = false
			boule.CanQuery = false
			boule.CanTouch = false
			boule.Material = Enum.Material.Neon
			boule.Color = (i == #points) and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 200, 60)
			boule.Position = p.Position
			boule.Parent = dossierDebug
		end
	end

	local function deconnecterBlocages()
		for _, c in connexionsBlocage do
			c:Disconnect()
		end
		table.clear(connexionsBlocage)
		cheminCoupe = false
	end

	local function reinitialiserSuivi()
		suiviIndex = nil
		ancrePosition, ancreDepuis = racine.Position, os.clock()
		reculJusqua, pointRecul = 0, nil
	end

	-- Chemin « normal » (sol plat). decalage = index, dans la liste finale, du point qui précède
	-- le premier point de ce morceau : sert à savoir si un obstacle coupe la partie encore à faire.
	local function cheminSimple(depuis: Vector3, but: Vector3, decalage: number)
		local chemin = PathfindingService:CreatePath({
			AgentRadius = R.AGENT_RAYON,
			AgentHeight = R.AGENT_HAUTEUR,
			AgentCanJump = false,
		})
		local ok = pcall(function()
			chemin:ComputeAsync(depuis, but)
		end)
		if not ok or chemin.Status ~= Enum.PathStatus.Success then
			chemin:Destroy()
			return nil
		end
		local liste = {}
		for _, wp in chemin:GetWaypoints() do
			table.insert(liste, { Position = wp.Position, Action = wp.Action })
		end
		-- un obstacle apparaît sur la partie du chemin pas encore parcourue : on recalcule
		table.insert(connexionsBlocage, chemin.Blocked:Connect(function(indexBloque)
			if decalage + indexBloque >= indexPoint then
				cheminCoupe = true
			end
		end))
		table.insert(connexionsBlocage, { Disconnect = function() chemin:Destroy() end })
		return liste
	end

	-- Points de guidage en ligne droite de « a » vers « b » (pour monter ou descendre l'escalier)
	local function ligne(a: Vector3, b: Vector3)
		local nombre = math.max(1, math.ceil((b - a).Magnitude / R.ECART_POINTS_ESCALIER))
		local liste = {}
		for i = 1, nombre do
			table.insert(liste, { Position = a:Lerp(b, i / nombre), Action = ACTION_MARCHE })
		end
		return liste
	end

	local function ajouter(liste, autres, depuisIndex)
		for i = depuisIndex or 1, #autres do
			table.insert(liste, autres[i])
		end
	end

	-- Calcule un chemin vers « but ». Renvoie true si un chemin existe.
	-- Si le calcul échoue, l'ancien chemin est gardé (il continue d'avancer).
	function self.calculer(but: Vector3): boolean
		local maintenant = os.clock()
		if maintenant < pauseCalculsJusqua then
			return false
		end
		local anciennesConnexions = table.clone(connexionsBlocage)
		table.clear(connexionsBlocage)

		local depuis = racine.Position
		local nouveau = {}
		local reussi = true
		local zoneDepart, zoneBut = terrain.zoneDe(depuis), terrain.zoneDe(but)

		if zoneDepart == zoneBut and zoneDepart ~= "escalier" then
			-- même étage, hors escalier : chemin normal
			local simple = cheminSimple(depuis, but, 0)
			if simple then
				nouveau = simple
			else
				reussi = false
			end
		elseif zoneDepart == "escalier" and zoneBut == "escalier" then
			-- tous les deux sur l'escalier : en ligne droite le long des marches
			nouveau = ligne(depuis, terrain.pointEscalier(but))
		else
			-- [chemin jusqu'à l'escalier] + [marches en ligne droite] + [chemin jusqu'au but]
			local function extremite(zone)
				return zone == "rdc" and terrain.escalierBas.Position or terrain.escalierHaut.Position
			end
			local debutEscalier = depuis -- déjà sur les marches
			if zoneDepart ~= "escalier" then
				debutEscalier = extremite(zoneDepart)
				local avant = cheminSimple(depuis, debutEscalier, 0)
				if avant then
					ajouter(nouveau, avant)
				else
					reussi = false
				end
			end
			if reussi then
				local finEscalier
				local apres = nil
				if zoneBut == "escalier" then
					finEscalier = terrain.pointEscalier(but)
				else
					finEscalier = extremite(zoneBut)
				end
				ajouter(nouveau, ligne(debutEscalier, finEscalier))
				if zoneBut ~= "escalier" then
					-- le 1er point de ce morceau est le haut/bas de l'escalier, déjà dans la liste
					apres = cheminSimple(finEscalier, but, #nouveau - 1)
					if apres then
						ajouter(nouveau, apres, 2)
					else
						reussi = false
					end
				end
			end
		end

		if not reussi then
			-- on garde l'ancien chemin et ses surveillances
			for _, c in connexionsBlocage do
				c:Disconnect()
			end
			table.clear(connexionsBlocage)
			for _, c in anciennesConnexions do
				table.insert(connexionsBlocage, c)
			end
			echecsDeSuite += 1
			if echecsDeSuite >= R.ECHECS_AVANT_PAUSE then
				echecsDeSuite = 0
				pauseCalculsJusqua = maintenant + R.PAUSE_APRES_ECHECS
			end
			return false
		end

		for _, c in anciennesConnexions do
			c:Disconnect()
		end
		cheminCoupe = false
		echecsDeSuite = 0
		points = nouveau
		indexPoint = math.min(2, #points) -- le premier point est la position actuelle
		butActuel = but
		reinitialiserSuivi()
		dessiner()
		return true
	end

	-- Secours quand le calcul échoue : un seul point, en ligne droite vers le but
	function self.direct(but: Vector3)
		deconnecterBlocages()
		points = { { Position = but, Action = ACTION_MARCHE } }
		indexPoint = 1
		butActuel = but
		reinitialiserSuivi()
		dessiner()
	end

	function self.vider()
		deconnecterBlocages()
		points = {}
		indexPoint = 1
		butActuel = nil
		blocages = 0
		reinitialiserSuivi()
	end

	function self.but(): Vector3?
		return butActuel
	end

	function self.estFini(): boolean
		return points[indexPoint] == nil
	end

	-- Bloqué : il recule en biais (derrière lui, d'un côté au hasard), puis recalculera
	local function commencerRecul(maintenant: number)
		local cf = racine.CFrame
		local cote = aleatoire:NextNumber() < 0.5 and -1 or 1
		pointRecul = racine.Position - cf.LookVector * R.RECUL_DECOINCAGE
			+ cf.RightVector * (cote * R.RECUL_DECOINCAGE * 0.6)
		reculJusqua = maintenant + R.DUREE_DECOINCAGE
		humanoid:MoveTo(pointRecul)
	end

	-- Avance vers le point en cours. Renvoie false quand le chemin est terminé
	-- (ou abandonné après deux blocages de suite).
	function self.suivre(): boolean
		local maintenant = os.clock()

		-- recul de décoinçage en cours
		if pointRecul then
			if maintenant < reculJusqua then
				humanoid:MoveTo(pointRecul)
				return true
			end
			pointRecul = nil
			if not butActuel or not self.calculer(butActuel) then
				self.vider()
				return false
			end
		end

		-- obstacle signalé sur le chemin restant
		if cheminCoupe and butActuel then
			cheminCoupe = false
			self.calculer(butActuel)
		end

		local point = points[indexPoint]
		if not point then
			return false
		end
		local ecart = point.Position - racine.Position
		local distanceH = Vector3.new(ecart.X, 0, ecart.Z).Magnitude -- on ignore la hauteur
		-- rayon d'arrivée jamais plus petit qu'un pas de décision (sinon il tourne autour du point)
		local rayon = math.max(R.DISTANCE_POINT, humanoid.WalkSpeed * R.PERIODE_DECISION * 1.5)
		if distanceH < rayon then
			indexPoint += 1
			blocages = 0
			point = points[indexPoint]
			if not point then
				return false
			end
			ecart = point.Position - racine.Position
			distanceH = Vector3.new(ecart.X, 0, ecart.Z).Magnitude
		end

		-- blocage : pas de rapprochement du point, ou corps immobile, pendant DELAI_BLOCAGE
		if suiviIndex ~= indexPoint then
			suiviIndex, suiviDistance, suiviDepuis = indexPoint, distanceH, maintenant
		elseif distanceH < suiviDistance - R.PROGRES_MIN then
			suiviDistance, suiviDepuis = distanceH, maintenant
		end
		if not ancrePosition or (racine.Position - ancrePosition).Magnitude > R.PROGRES_MIN * 2 then
			ancrePosition, ancreDepuis = racine.Position, maintenant
		end
		if maintenant - suiviDepuis > R.DELAI_BLOCAGE or maintenant - ancreDepuis > R.DELAI_BLOCAGE then
			blocages += 1
			suiviIndex = nil
			ancrePosition, ancreDepuis = racine.Position, maintenant
			if blocages >= 2 or not butActuel then
				self.vider()
				return false
			end
			commencerRecul(maintenant)
			return true
		end

		if point.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(point.Position)
		return true
	end

	-- Va droit vers un point sans chemin (tout près du joueur)
	function self.foncer(but: Vector3)
		self.vider()
		humanoid:MoveTo(but)
	end

	-- S'arrêter sur place et pouvoir se tourner soi-même (regarder autour, faire face)
	function self.arreter()
		self.vider()
		humanoid:MoveTo(racine.Position)
		humanoid.AutoRotate = false
	end

	function self.repartir()
		humanoid.AutoRotate = true
	end

	-- Angle horizontal (lacet) d'une direction, au sens de CFrame.Angles(0, lacet, 0)
	function self.lacetDe(direction: Vector3): number
		return math.atan2(-direction.X, -direction.Z)
	end

	function self.orienter(lacet: number, douceur: number)
		local voulu = CFrame.new(racine.Position) * CFrame.Angles(0, lacet, 0)
		racine.CFrame = racine.CFrame:Lerp(voulu, douceur)
	end

	-- Se tourner vers un point (s'il n'est pas juste sous ses pieds)
	function self.faireFace(point: Vector3, douceur: number)
		local ecart = point - racine.Position
		if Vector3.new(ecart.X, 0, ecart.Z).Magnitude > 0.1 then
			self.orienter(self.lacetDe(ecart), douceur)
		end
	end

	return self
end

return Deplacement
