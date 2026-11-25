--!strict
--[[
	Rôle    : stratégie d'utilisation « Nettoyage » (balai, aspirateur).
	          Fait avancer la progression sur la cible (attribut Progression) : durée de la cible
	          (DureeNettoyage, posée par Taches.server) divisée par la vitesse de l'outil.
	          Tout nettoyage fait du bruit : à intervalle régulier, le serveur prévient le monstre
	          (MonstreBruit : position de la tache, portée de l'outil x FacteurBruit de la tache,
	          joueur qui nettoie). Le client n'envoie jamais de bruit : il ne peut ni l'inventer ni le taire.
	          Efface la saleté quand elle est propre. La progression reste sur la cible si on
	          s'arrête : un autre joueur (ou une autre tentative) reprend là où c'était.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24 (modifié : 2026-11-25, vitesse de l'outil, bruit pour tous les outils, halo éteint)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local DefinitionsOutils = require(Partage:WaitForChild("DefinitionsOutils"))
local LigneDeVue = require(Partage:WaitForChild("LigneDeVue"))

local Reglages = DefinitionsOutils.Reglages

local DUREE_EFFACEMENT = 0.8 -- secondes pour que la saleté devienne transparente
local VITESSE_MIN = 0.1      -- garde-fou : une vitesse d'outil absurde ne gèle pas la progression
local FACTEUR_BRUIT_MIN = 0.25 -- garde-fou sur l'attribut FacteurBruit de la tache
local FACTEUR_BRUIT_MAX = 3

-- Ce dont la stratégie a besoin (injecté par Outils.server)
export type Evenements = {
	progression: BindableEvent,
	termine: BindableEvent,
	bruitMonstre: BindableEvent,
}

local Nettoyage = {}

-- Nombre fini d'un attribut de la cible, ou nil (absent, autre type, NaN, infini)
local function nombreAttribut(cible: Instance, nom: string): number?
	local valeur = cible:GetAttribute(nom)
	if type(valeur) ~= "number" or valeur ~= valeur or math.abs(valeur) == math.huge then
		return nil
	end
	return valeur
end

-- Fait disparaître la cible en fondu (elle-même si c'est une BasePart, et ses descendants :
-- parties, décalques, et lumières comme le halo des taches).
-- Comportement « la saleté disparaît » : voir Taches-de-menage.md (coffre Obsidian).
-- On ne détruit PAS la cible : le futur TaskManager peut encore la lire.
local function effacer(cible: Instance)
	local elements: { Instance } = { cible }
	for _, descendant in cible:GetDescendants() do
		table.insert(elements, descendant)
	end

	local infos = TweenInfo.new(DUREE_EFFACEMENT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local parties: { BasePart } = {}
	local lumieres: { Light } = {}

	for _, element in elements do
		if element:IsA("BasePart") then
			table.insert(parties, element)
			TweenService:Create(element, infos, { Transparency = 1 }):Play()
		elseif element:IsA("Decal") or element:IsA("Texture") then
			TweenService:Create(element, infos, { Transparency = 1 }):Play()
		elseif element:IsA("Light") then
			-- le halo d'une tache (PointLight) s'éteint avec elle
			table.insert(lumieres, element)
			TweenService:Create(element, infos, { Brightness = 0 }):Play()
		end
	end

	-- Une fois invisible, la saleté ne bloque plus rien et n'est plus détectée
	task.delay(DUREE_EFFACEMENT, function()
		for _, partie in parties do
			partie.CanCollide = false
			partie.CanQuery = false
			partie.CanTouch = false
		end
		for _, lumiere in lumieres do
			lumiere.Enabled = false
		end
	end)
end

function Nettoyage.nouveau(evenements: Evenements): Types.StrategieUtilisation
	local function commencer(session: Types.SessionUtilisation): (boolean, string?)
		if session.cible:GetAttribute(Reglages.ATTRIBUT_NETTOYE) == true then
			return false, "indisponible"
		end
		session.donnees.dernierBruit = -math.huge
		return true, nil
	end

	local function avancer(session: Types.SessionUtilisation, dt: number): Types.ResultatAvance
		local cible = session.cible
		local definition = session.definition

		-- Durée propre à la cible si elle en a une (Taches.server la pose), sinon celle de l'outil
		local duree: number = definition.dureeUtilisation
		local dureeCible = nombreAttribut(cible, Reglages.ATTRIBUT_DUREE)
		if dureeCible ~= nil and dureeCible > 0 then
			duree = dureeCible
		end
		-- Un outil plus rapide fait avancer la progression plus vite (aspirateur : x1,6)
		local vitesse = math.max(definition.vitesseNettoyage, VITESSE_MIN)

		local actuelle = nombreAttribut(cible, Reglages.ATTRIBUT_PROGRESSION) or 0
		local progression = math.clamp(actuelle + dt * vitesse / duree, 0, 1)
		cible:SetAttribute(Reglages.ATTRIBUT_PROGRESSION, progression)
		evenements.progression:Fire(session.joueur, cible, progression, definition.id)

		-- Tout nettoyage fait du bruit pour le monstre, à intervalle régulier
		-- (le premier bruit part dès le début : commencer() met dernierBruit à -infini)
		local bruit = definition.bruit
		if bruit then
			local dernierBruit = session.donnees.dernierBruit
			if type(dernierBruit) ~= "number" then
				dernierBruit = -math.huge
			end
			if os.clock() - (dernierBruit :: number) >= bruit.periode then
				local position = LigneDeVue.pointCentral(cible)
				if not position then
					local poignee = session.outil:FindFirstChild("Handle")
					if poignee and poignee:IsA("BasePart") then
						position = poignee.Position
					end
				end
				if position then
					-- une tache murale (slime) s'entend plus loin qu'une tache au sol : FacteurBruit
					local facteur = math.clamp(nombreAttribut(cible, Reglages.ATTRIBUT_FACTEUR_BRUIT) or 1, FACTEUR_BRUIT_MIN, FACTEUR_BRUIT_MAX)
					-- 3e argument : le joueur qui nettoie (le monstre peut l'avertir, voir MonstreIA)
					evenements.bruitMonstre:Fire(position, bruit.portee * facteur, session.joueur)
				end
				session.donnees.dernierBruit = os.clock()
			end
		end

		if progression >= 1 then
			return "fini"
		end
		return "continue"
	end

	local function finir(session: Types.SessionUtilisation, raison: string)
		if raison ~= "fini" then
			return -- arrêt, départ, invalide : la progression reste sur la cible
		end
		local cible = session.cible
		local definition = session.definition
		if cible:GetAttribute(Reglages.ATTRIBUT_NETTOYE) == true then
			return
		end

		cible:SetAttribute(Reglages.ATTRIBUT_NETTOYE, true)
		CollectionService:RemoveTag(cible, definition.tagCible)
		evenements.termine:Fire(session.joueur, cible, definition.id)
		effacer(cible)
	end

	return {
		commencer = commencer,
		avancer = avancer,
		finir = finir,
	}
end

return Nettoyage
