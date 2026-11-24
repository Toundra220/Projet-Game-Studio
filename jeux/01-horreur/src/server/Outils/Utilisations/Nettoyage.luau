--!strict
--[[
	Rôle    : stratégie d'utilisation « Nettoyage » (balai, aspirateur).
	          Fait avancer la progression sur la cible (attribut Progression), envoie du bruit
	          au monstre si l'outil en fait, et efface la saleté quand elle est propre.
	          La progression reste sur la cible si on s'arrête : un autre joueur (ou une autre
	          tentative) reprend là où c'était.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
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

-- Ce dont la stratégie a besoin (injecté par Outils.server)
export type Evenements = {
	progression: BindableEvent,
	termine: BindableEvent,
	bruitMonstre: BindableEvent,
}

local Nettoyage = {}

-- Fait disparaître la cible en fondu (elle-même si c'est une BasePart, et ses descendants).
-- Comportement « la saleté disparaît » : voir Taches-de-menage.md (coffre Obsidian).
-- On ne détruit PAS la cible : le futur TaskManager peut encore la lire.
local function effacer(cible: Instance)
	local elements: { Instance } = { cible }
	for _, descendant in cible:GetDescendants() do
		table.insert(elements, descendant)
	end

	local infos = TweenInfo.new(DUREE_EFFACEMENT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local parties: { BasePart } = {}

	for _, element in elements do
		if element:IsA("BasePart") then
			table.insert(parties, element)
			TweenService:Create(element, infos, { Transparency = 1 }):Play()
		elseif element:IsA("Decal") or element:IsA("Texture") then
			TweenService:Create(element, infos, { Transparency = 1 }):Play()
		end
	end

	-- Une fois invisible, la saleté ne bloque plus rien et n'est plus détectée
	task.delay(DUREE_EFFACEMENT, function()
		for _, partie in parties do
			partie.CanCollide = false
			partie.CanQuery = false
			partie.CanTouch = false
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

		-- Durée propre à la cible si elle en a une, sinon celle de l'outil
		local duree = cible:GetAttribute(Reglages.ATTRIBUT_DUREE)
		if type(duree) ~= "number" or duree <= 0 then
			duree = definition.dureeUtilisation
		end

		local actuelle = cible:GetAttribute(Reglages.ATTRIBUT_PROGRESSION)
		if type(actuelle) ~= "number" then
			actuelle = 0
		end
		local progression = math.clamp((actuelle :: number) + dt / (duree :: number), 0, 1)
		cible:SetAttribute(Reglages.ATTRIBUT_PROGRESSION, progression)
		evenements.progression:Fire(session.joueur, cible, progression, definition.id)

		-- Bruit pour le monstre (aspirateur), à intervalle régulier
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
					evenements.bruitMonstre:Fire(position, bruit.portee)
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
