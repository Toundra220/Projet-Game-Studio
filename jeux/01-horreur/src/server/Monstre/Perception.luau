--[[
	Rôle    : les sens du monstre. Écrit des faits dans « memoire » ; les états les lisent
	          et ne lancent jamais de rayon eux-mêmes (skill game-ai : perceive -> decide).
	          Vue  : distance, puis cône (portée réduite sur les bords), puis rayons vers le torse
	                 et la tête (les pièces presque invisibles ne bloquent pas). Vigilance qui monte
	                 plus vite quand le joueur est proche : il ne réagit pas instantanément.
	          Ouïe : seulement les bruits reçus par MonstreBruit (pas, actions et nettoyage, chacun
	                 avec un stade : voir ReactionBruit). Les pas ne sont plus mesurés ici :
	                 Server/Bruit calcule le niveau de chaque joueur et l'envoie. Un bruit lointain
	                 est mal situé : il va vers une position estimée, pas vers la vraie.
	                 Entre deux bruits en attente, le plus attirant l'emporte (stade, puis intensité).
	          Pas d'omniscience : il ne lit la position d'un joueur que quand il le voit.
	Origine : ÉCRIT PAR CLAUDE (extrait et complété de MonstreIA.server.luau)
	Auteur  : Romain Lesur
	Date    : 2026-11-24 (modifié : 2026-11-25, bruits ramenés au sol, source du bruit ; stades de bruit)
]]

local Players = game:GetService("Players")

local Perception = {}

-- ctx = { reglages, racine, tete (BasePart ou nil), terrain, exclusVue, reaction (ReactionBruit) }
function Perception.nouveau(ctx)
	local R = ctx.reglages
	local racine: BasePart = ctx.racine
	local tete: BasePart? = ctx.tete
	local terrain = ctx.terrain
	local reaction = ctx.reaction
	local aleatoire = Random.new()

	local paramsVue = RaycastParams.new()
	paramsVue.FilterType = Enum.RaycastFilterType.Exclude
	paramsVue.FilterDescendantsInstances = ctx.exclusVue
	paramsVue.IgnoreWater = true

	local self = {}

	-- Tableau noir : faits connus du monstre
	local memoire = {
		cible = nil,                 -- joueur repéré (Player)
		voitCible = false,           -- il le voit en ce moment
		dernierePosition = nil,      -- là où il l'a vu en dernier (au sol)
		derniereVitesse = Vector3.zero,
		finPoursuite = -math.huge,   -- moment où il a perdu le joueur
		bruit = nil,                 -- { brut, estime, intensite, instant, source, stade } : dernier bruit pas encore traité (source : Player ou nil)
		soupcon = 0,                 -- vigilance la plus haute parmi les joueurs pas encore repérés (0..1)
		indice = nil,                -- endroit (au sol) où il a entrevu quelqu'un
		indiceVu = false,            -- il entrevoit quelqu'un en ce moment
	}
	self.memoire = memoire

	local vigilance = {}     -- [joueur] = 0..1 : à 1, il a repéré le joueur
	local ignorerJusqua = {} -- [joueur] = moment jusqu'auquel il l'ignore (répit après une prise)

	function self.positionYeux(): Vector3
		if tete then
			return tete.Position
		end
		return racine.Position + Vector3.new(0, R.HAUTEUR_YEUX, 0)
	end

	-- Rien ne bloque la vue entre « depuis » et « point » (le personnage visé ne compte pas).
	-- Une pièce presque invisible est traversée (4 fois max).
	local function ligneDeVue(depuis: Vector3, perso: Model, point: Vector3): boolean
		local origine = depuis
		for _ = 1, 4 do
			local direction = point - origine
			if direction.Magnitude < 0.05 then
				return true
			end
			local resultat = workspace:Raycast(origine, direction, paramsVue)
			if resultat == nil or resultat.Instance:IsDescendantOf(perso) then
				return true
			end
			if resultat.Instance.Transparency < R.TRANSPARENCE_TRAVERSEE then
				return false
			end
			origine = resultat.Position + direction.Unit * 0.05
		end
		return false
	end

	function self.ignorer(joueur: Player, jusqua: number)
		ignorerJusqua[joueur] = jusqua
		vigilance[joueur] = 0
	end

	-- Joueur à ignorer : répit après une prise, ou invulnérable (attribut posé par Vies.server)
	function self.estIgnore(joueur: Player, maintenant: number): boolean
		return (ignorerJusqua[joueur] or 0) > maintenant or joueur:GetAttribute("Invulnerable") == true
	end

	function self.oublier(joueur: Player)
		vigilance[joueur] = nil
		ignorerJusqua[joueur] = nil
		if memoire.cible == joueur then
			memoire.cible = nil
			memoire.voitCible = false
		end
	end

	function self.vigilanceDe(joueur: Player): number
		return vigilance[joueur] or 0
	end

	-- Un bruit à « position », audible jusqu'à « portee ». Renvoie true s'il l'a entendu.
	-- « source » (facultatif) : le joueur qui fait le bruit, pour pouvoir l'avertir.
	-- « stade » : 1 (marche) ... STADE_MAX (nettoyage), déjà validé par ReactionBruit.normaliser.
	-- Le bruit est ramené au sol, comme le monstre : une tache au mur est en hauteur, mais c'est au
	-- pied du mur qu'il va, et sa hauteur ne compte pas comme un étage de plus dans la distance.
	function self.entendre(position: Vector3, portee: number, source: Player?, stade: number): boolean
		local sol = terrain.auSol(position)
		local ecart = sol - terrain.auSol(racine.Position)
		local distance = Vector3.new(ecart.X, ecart.Y * R.FACTEUR_ETAGE, ecart.Z).Magnitude
		if portee <= 0 or distance > portee then
			return false
		end
		local intensite = 1 - distance / portee
		local enAttente = memoire.bruit
		if enAttente and os.clock() - enAttente.instant < 1
			and reaction.plusFort(enAttente.stade, enAttente.intensite, stade, intensite) then
			return false -- un bruit plus attirant attend déjà d'être traité
		end
		-- de loin, il situe mal le bruit
		local erreur = math.min(R.IMPRECISION_MAX, distance * R.IMPRECISION_OUIE) * aleatoire:NextNumber()
		local angle = aleatoire:NextNumber() * 2 * math.pi
		memoire.bruit = {
			brut = sol,
			estime = sol + Vector3.new(math.cos(angle), 0, math.sin(angle)) * erreur,
			intensite = intensite,
			instant = os.clock(),
			source = source,
			stade = stade,
		}
		return true
	end

	-- Prend le bruit en attente (nil s'il n'y en a pas ou s'il est trop vieux)
	function self.prendreBruit()
		local bruit = memoire.bruit
		memoire.bruit = nil
		if bruit and os.clock() - bruit.instant < R.DUREE_VIE_BRUIT then
			return bruit
		end
		return nil
	end

	-- enChasse : il poursuit déjà quelqu'un (portée de vue plus longue pour sa cible)
	function self.percevoir(dt: number, maintenant: number, enChasse: boolean)
		local yeux = self.positionYeux()
		local devant = racine.CFrame.LookVector
		local portee = enChasse and R.PORTEE_VUE_POURSUITE or R.PORTEE_VUE
		local demiAngle = math.rad(R.DEMI_ANGLE_VUE_DEG)

		local meilleur, meilleurScore, infoMeilleur = nil, math.huge, nil
		local soupconMax, indice = 0, nil

		for _, joueur in Players:GetPlayers() do
			local perso = joueur.Character
			local r = perso and perso:FindFirstChild("HumanoidRootPart")
			local h = perso and perso:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 and not self.estIgnore(joueur, maintenant) then
				local vecteur = r.Position - yeux
				local distance = vecteur.Magnitude
				local estLaCible = enChasse and joueur == memoire.cible
				local voit = false

				-- du moins cher au plus cher : distance, puis cône, puis rayons
				if distance < portee then
					local dansChamp = distance < R.PORTEE_PROXIMITE
					if not dansChamp and distance > 0 then
						local angle = math.acos(math.clamp(devant:Dot(vecteur / distance), -1, 1))
						if angle <= demiAngle then
							-- vision périphérique : il voit moins loin sur les côtés
							local porteeAngle = portee * (1 - (1 - R.PORTEE_BORD_VUE) * (angle / demiAngle))
							dansChamp = estLaCible or distance < porteeAngle
						end
					end
					if dansChamp then
						local teteJoueur = perso:FindFirstChild("Head")
						voit = ligneDeVue(yeux, perso, r.Position)
						if not voit and teteJoueur and teteJoueur:IsA("BasePart") then
							voit = ligneDeVue(yeux, perso, teteJoueur.Position)
						end
					end
				end

				local v = vigilance[joueur] or 0
				if voit then
					if estLaCible then
						v = 1 -- il sait qui il poursuit : pas de nouveau temps de réaction
					else
						local t = math.clamp((distance - R.PORTEE_PROXIMITE) / (R.PORTEE_VUE - R.PORTEE_PROXIMITE), 0, 1)
						local tempsReaction = R.TEMPS_REACTION_PRES + (R.TEMPS_REACTION_LOIN - R.TEMPS_REACTION_PRES) * t
						v = math.min(1, v + dt / tempsReaction)
					end
					if v >= 1 then
						-- il garde de préférence la cible qu'il poursuit déjà, sinon la plus proche
						local score = (joueur == memoire.cible) and -1 or distance
						if score < meilleurScore then
							meilleur, meilleurScore = joueur, score
							infoMeilleur = { position = r.Position, vitesse = r.AssemblyLinearVelocity }
						end
					elseif v > soupconMax then
						soupconMax, indice = v, r.Position
					end
				else
					v = math.max(0, v - dt * R.OUBLI_VIGILANCE)
				end
				vigilance[joueur] = v
				-- ouïe : les pas arrivent par MonstreBruit (Server/Bruit), plus rien à mesurer ici
			end
		end

		if meilleur then
			memoire.cible = meilleur
			memoire.voitCible = true
			memoire.dernierePosition = terrain.auSol(infoMeilleur.position)
			memoire.derniereVitesse = infoMeilleur.vitesse
		else
			memoire.voitCible = false
		end
		memoire.soupcon = soupconMax
		memoire.indiceVu = indice ~= nil
		if indice then
			memoire.indice = terrain.auSol(indice)
		end
	end

	return self
end

return Perception
