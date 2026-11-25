--!strict
--[[
	Rôle    : fait vivre les gouttes de slime : un petit pool de parties locales (sans collision,
	          visibles seulement par ce joueur) que l'on recycle. Une goutte passe par 4 états :
	          formation (elle grossit et s'allonge au bas de la coulure) -> chute (gravité lente,
	          étirée par la vitesse) -> flaque (disque plat qui s'étale puis disparaît en fondu)
	          + quelques éclats (mini gouttes qui rebondissent). Le module ne décide pas QUAND
	          lancer une goutte ni OÙ est le sol : l'appelant donne la source et la hauteur du sol
	          (voir GouttesSlime.client). Purement visuel : aucun réseau, aucune collision.
	          Les chiffres viennent de Shared/Taches/ReglagesGouttes (passés en paramètre).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]

export type Animateur = {
	lancerGoutte: (proprietaire: Instance, source: Vector3, solY: number) -> boolean,
	abandonner: (proprietaire: Instance) -> (),
	nombreDe: (proprietaire: Instance) -> number,
	nombreTotal: () -> number,
	mettreAJour: (dt: number) -> (),
	detruire: () -> (),
}

type Entree = {
	genre: string, -- "formation" | "chute" | "flaque" | "eclat"
	partie: Part,
	proprietaire: Instance?, -- la tache d'où vient la goutte (nil pour flaque et éclats)
	t: number,
	duree: number,
	diametre: number,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	solY: number,
	rayon: number,
}

local Animateur = {}

local function lissage(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function aleatoire(rng: Random, minimum: number, maximum: number): number
	return minimum + (maximum - minimum) * rng:NextNumber()
end

local ROTATION_A_PLAT = CFrame.Angles(0, 0, math.pi / 2) -- un cylindre Roblox a son axe sur X : on le couche

function Animateur.nouveau(reglages: any, parent: Instance): Animateur
	local rng = Random.new()
	local libres: { Part } = {}
	local creees = 0
	local entrees: { Entree } = {}
	local totalGouttes = 0 -- formation + chute

	local function obtenirPartie(): Part?
		local partie = table.remove(libres)
		if partie == nil then
			if creees >= reglages.PARTIES_MAX then
				return nil
			end
			creees += 1
			local nouvelle = Instance.new("Part")
			nouvelle.Name = "GouttePool"
			nouvelle.Anchored = true
			nouvelle.CanCollide = false -- jamais d'effet sur le joueur ni le monstre
			nouvelle.CanQuery = false   -- invisible pour les rayons (outils, vue du monstre)
			nouvelle.CanTouch = false
			nouvelle.CastShadow = false
			nouvelle.Massless = true
			nouvelle.Color = reglages.COULEUR
			nouvelle.Material = reglages.MATIERE
			nouvelle.Reflectance = reglages.REFLECTANCE
			nouvelle.TopSurface = Enum.SurfaceType.Smooth
			nouvelle.BottomSurface = Enum.SurfaceType.Smooth
			partie = nouvelle
		end
		local p = partie :: Part
		p.Parent = parent
		return p
	end

	local function rendrePartie(partie: Part)
		partie.Parent = nil
		table.insert(libres, partie)
	end

	local function retirer(index: number)
		local entree = entrees[index]
		if entree.genre == "formation" or entree.genre == "chute" then
			totalGouttes -= 1
		end
		rendrePartie(entree.partie)
		local dernier = #entrees
		entrees[index] = entrees[dernier]
		entrees[dernier] = nil :: any
	end

	local function nouvelleEntree(genre: string, partie: Part, proprietaire: Instance?): Entree
		return {
			genre = genre, partie = partie, proprietaire = proprietaire,
			t = 0, duree = 1, diametre = 0.3,
			x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0, solY = 0, rayon = 0,
		}
	end

	local function placerBoule(entree: Entree, tailleXZ: number, tailleY: number, centreY: number)
		local p = entree.partie
		p.Size = Vector3.new(tailleXZ, tailleY, tailleXZ)
		p.CFrame = CFrame.new(entree.x, centreY, entree.z)
	end

	-- La goutte touche le sol : elle devient une flaque et jette quelques éclats
	local function eclabousser(entree: Entree)
		local diametre = entree.diametre
		local partie = entree.partie
		entree.genre = "flaque"
		entree.t = 0
		entree.duree = aleatoire(rng, reglages.FLAQUE_DUREE_MIN, reglages.FLAQUE_DUREE_MAX)
		entree.rayon = diametre * aleatoire(rng, reglages.FLAQUE_RAYON_FACTEUR_MIN, reglages.FLAQUE_RAYON_FACTEUR_MAX) / 2
		entree.y = entree.solY + reglages.FLAQUE_DECALAGE_SOL
		partie.Shape = Enum.PartType.Cylinder
		partie.Transparency = reglages.FLAQUE_TRANSPARENCE_DEBUT
		totalGouttes -= 1

		local nombre = rng:NextInteger(reglages.ECLATS_MIN, reglages.ECLATS_MAX)
		for _ = 1, nombre do
			local autre = obtenirPartie()
			if autre == nil then
				break
			end
			local eclat = nouvelleEntree("eclat", autre, nil)
			local angle = rng:NextNumber() * math.pi * 2
			local lateral = aleatoire(rng, reglages.ECLAT_VITESSE_LATERALE_MIN, reglages.ECLAT_VITESSE_LATERALE_MAX)
			eclat.diametre = diametre * reglages.ECLAT_DIAMETRE_FACTEUR * aleatoire(rng, 0.7, 1.2)
			eclat.x, eclat.y, eclat.z = entree.x, entree.solY + eclat.diametre / 2, entree.z
			eclat.vx, eclat.vz = math.cos(angle) * lateral, math.sin(angle) * lateral
			eclat.vy = aleatoire(rng, reglages.ECLAT_VITESSE_HAUTE_MIN, reglages.ECLAT_VITESSE_HAUTE_MAX)
			eclat.solY = entree.solY
			eclat.duree = 1.5 -- sécurité : un éclat ne vit jamais plus longtemps
			autre.Shape = Enum.PartType.Ball
			autre.Transparency = reglages.TRANSPARENCE_GOUTTE
			autre.Size = Vector3.new(eclat.diametre, eclat.diametre, eclat.diametre)
			autre.CFrame = CFrame.new(eclat.x, eclat.y, eclat.z)
			table.insert(entrees, eclat)
		end
	end

	local function mettreAJourEntree(entree: Entree, dt: number): boolean -- vrai = terminée
		entree.t += dt
		local genre = entree.genre

		if genre == "formation" then
			local avancement = math.clamp(entree.t / entree.duree, 0, 1)
			local grossissement = lissage(avancement / 0.85) -- pleine taille aux 85 % puis ça s'étire
			local diametre = entree.diametre
			local taille = math.max(diametre * grossissement, 0.05)
			local debutEtirement = 1 - reglages.PART_ALLONGEMENT
			local u = math.clamp((avancement - debutEtirement) / reglages.PART_ALLONGEMENT, 0, 1)
			local etirement = 1 + reglages.ALLONGEMENT_FORMATION * u * u
			local tailleY = taille * etirement
			local tailleXZ = taille / math.sqrt(etirement) -- le volume ne change presque pas
			-- accrochée en haut : le haut de la goutte reste à la source, le bas descend
			entree.y = entree.vy - tailleY / 2 -- vy sert ici à garder la hauteur de la source
			placerBoule(entree, tailleXZ, tailleY, entree.y)
			if avancement >= 1 then
				entree.genre = "chute"
				entree.t = 0
				entree.vy = 0 -- la goutte se détache : elle part sans vitesse, au centre où elle pendait
			end
			return false
		end

		if genre == "chute" then
			entree.vy += reglages.GRAVITE * dt
			entree.y -= entree.vy * dt
			local etirement = 1 + math.min(entree.vy * reglages.ETIREMENT_VITESSE, reglages.ETIREMENT_MAX)
			local tailleY = entree.diametre * etirement
			local tailleXZ = entree.diametre / math.sqrt(etirement)
			if entree.y - tailleY / 2 <= entree.solY then
				eclabousser(entree)
				return false
			end
			placerBoule(entree, tailleXZ, tailleY, entree.y)
			return false
		end

		if genre == "flaque" then
			local etalement = 1 - (1 - lissage(entree.t / reglages.FLAQUE_ETALEMENT_DUREE)) ^ 2
			local fondu = lissage((entree.t - reglages.FLAQUE_ETALEMENT_DUREE) / entree.duree)
			local rayon = entree.rayon * etalement * (1 + 0.15 * fondu)
			local diametre = math.max(rayon * 2, 0.05)
			entree.partie.Size = Vector3.new(reglages.FLAQUE_EPAISSEUR, diametre, diametre)
			entree.partie.CFrame = CFrame.new(entree.x, entree.y, entree.z) * ROTATION_A_PLAT
			entree.partie.Transparency = reglages.FLAQUE_TRANSPARENCE_DEBUT
				+ (1 - reglages.FLAQUE_TRANSPARENCE_DEBUT) * fondu
			return entree.t >= reglages.FLAQUE_ETALEMENT_DUREE + entree.duree
		end

		-- éclat : petit saut balistique, disparaît en retombant au sol
		entree.vy -= reglages.ECLAT_GRAVITE * dt
		entree.x += entree.vx * dt
		entree.y += entree.vy * dt
		entree.z += entree.vz * dt
		if entree.y - entree.diametre / 2 <= entree.solY or entree.t >= entree.duree then
			return true
		end
		entree.partie.CFrame = CFrame.new(entree.x, entree.y, entree.z)
		return false
	end

	local objet = {} :: Animateur

	-- source : point le plus bas de la coulure (déjà décalé devant le mur) ; solY : hauteur du sol sous la source
	objet.lancerGoutte = function(proprietaire: Instance, source: Vector3, solY: number): boolean
		if totalGouttes >= reglages.GOUTTES_MAX_TOTAL then
			return false
		end
		local partie = obtenirPartie()
		if partie == nil then
			return false
		end
		local entree = nouvelleEntree("formation", partie, proprietaire)
		entree.diametre = aleatoire(rng, reglages.DIAMETRE_MIN, reglages.DIAMETRE_MAX)
		entree.duree = aleatoire(rng, reglages.FORMATION_DUREE_MIN, reglages.FORMATION_DUREE_MAX)
		entree.x, entree.z = source.X, source.Z
		entree.vy = source.Y -- hauteur de la source, gardée en formation (voir mettreAJourEntree)
		entree.y = source.Y
		entree.solY = solY
		partie.Shape = Enum.PartType.Ball
		partie.Transparency = reglages.TRANSPARENCE_GOUTTE
		partie.Size = Vector3.new(0.05, 0.05, 0.05)
		partie.CFrame = CFrame.new(source)
		table.insert(entrees, entree)
		totalGouttes += 1
		return true
	end

	-- La tache est nettoyée, trop loin ou hors streaming : ses gouttes en formation disparaissent,
	-- celles qui tombent finissent leur chute (elles sont déjà détachées du mur)
	objet.abandonner = function(proprietaire: Instance)
		for i = #entrees, 1, -1 do
			local entree = entrees[i]
			if entree.proprietaire == proprietaire and entree.genre == "formation" then
				retirer(i)
			end
		end
	end

	objet.nombreDe = function(proprietaire: Instance): number
		local n = 0
		for _, entree in entrees do
			if entree.proprietaire == proprietaire and (entree.genre == "formation" or entree.genre == "chute") then
				n += 1
			end
		end
		return n
	end

	objet.nombreTotal = function(): number
		return #entrees
	end

	objet.mettreAJour = function(dt: number)
		for i = #entrees, 1, -1 do
			if mettreAJourEntree(entrees[i], dt) then
				retirer(i)
			end
		end
	end

	objet.detruire = function()
		for i = #entrees, 1, -1 do
			retirer(i)
		end
		for _, partie in libres do
			partie:Destroy()
		end
		table.clear(libres)
	end

	return objet
end

return Animateur
