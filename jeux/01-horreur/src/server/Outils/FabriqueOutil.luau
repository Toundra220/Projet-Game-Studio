--!strict
--[[
	Rôle    : fabrique un Tool prêt à être donné à un joueur.
	          1) si ServerStorage.Outils.<id> existe (Tool fait dans Studio), on le clone ;
	          2) sinon on convertit un clone de l'objet du décor en Tool
	          (poignée « Handle », autres parties soudées à la poignée).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))
local DefinitionsOutils = require(Partage:WaitForChild("DefinitionsOutils"))

local Reglages = DefinitionsOutils.Reglages

local NOM_DOSSIER_MODELES = "Outils" -- ServerStorage.Outils (optionnel)
local NOM_POIGNEE = "Handle"

local FabriqueOutil = {}

-- Retire tous les tags du Tool et de ses descendants : sinon le client verrait
-- le Tool copié comme un objet « Ramassable » du décor.
local function retirerTags(racine: Instance)
	local instances = racine:GetDescendants()
	table.insert(instances, racine)
	for _, instance in instances do
		for _, tag in CollectionService:GetTags(instance) do
			CollectionService:RemoveTag(instance, tag)
		end
	end
end

-- Supprime les scripts du clone : un objet du décor ne doit pas exécuter de code chez le joueur.
local function retirerScripts(racine: Instance)
	for _, instance in racine:GetDescendants() do
		if instance:IsA("Script") or instance:IsA("LocalScript") then
			instance:Destroy()
		end
	end
end

-- Supprime les soudures existantes du clone : on resoude tout à la poignée juste après
-- (une soudure entre deux parties qui ne touche pas la poignée laisserait tomber ces parties).
local function retirerSoudures(racine: Instance)
	for _, instance in racine:GetDescendants() do
		if instance:IsA("JointInstance") or instance:IsA("WeldConstraint") then
			instance:Destroy()
		end
	end
end

-- Poignée : BasePart « Handle » (descendante), sinon PrimaryPart, sinon 1re BasePart.
local function trouverPoignee(clone: Instance): BasePart?
	if clone:IsA("BasePart") then
		return clone
	end
	local candidate = clone:FindFirstChild(NOM_POIGNEE, true)
	if candidate and candidate:IsA("BasePart") then
		return candidate
	end
	if clone:IsA("Model") and clone.PrimaryPart then
		return clone.PrimaryPart
	end
	return clone:FindFirstChildWhichIsA("BasePart", true)
end

-- Finit le Tool : tags retirés, scripts retirés, attributs posés.
local function finaliser(tool: Tool, definition: Types.DefinitionOutil): Tool
	retirerScripts(tool)
	retirerTags(tool)
	tool:SetAttribute(Reglages.ATTRIBUT_OUTIL, definition.id)
	tool:SetAttribute(Reglages.ATTRIBUT_EN_UTILISATION, false)
	if definition.prise then
		tool.Grip = definition.prise
	end
	return tool
end

-- Convertit un clone de l'objet du décor en Tool. nil si aucune BasePart.
local function convertirDecor(definition: Types.DefinitionOutil, objetDecor: Instance): Tool?
	local clone = objetDecor:Clone()
	retirerScripts(clone)
	retirerTags(clone)

	local poignee = trouverPoignee(clone)
	if not poignee then
		warn("FabriqueOutil : aucune partie dans l'objet du décor pour " .. definition.id)
		clone:Destroy()
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = string.upper(string.sub(definition.nomAffiche, 1, 1)) .. string.sub(definition.nomAffiche, 2)
	tool.ToolTip = definition.verbeUtilisation
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	if clone:IsA("BasePart") then
		clone.Parent = tool
	else
		for _, enfant in clone:GetChildren() do
			enfant.Parent = tool
		end
		clone:Destroy()
	end

	poignee.Name = NOM_POIGNEE
	poignee.Parent = tool -- la poignée doit être enfant DIRECT du Tool
	retirerSoudures(tool)

	-- 1) chaque partie est soudée à la poignée avec un Weld dont le C0 est calculé à partir
	--    des positions du décor : la forme de l'objet est conservée, sans dépendre du workspace.
	local parties: { BasePart } = {}
	for _, instance in tool:GetDescendants() do
		if instance:IsA("BasePart") then
			table.insert(parties, instance)
		end
	end
	for _, partie in parties do
		if partie ~= poignee then
			local soudure = Instance.new("Weld")
			soudure.Name = "SoudurePoignee"
			soudure.Part0 = poignee
			soudure.Part1 = partie
			soudure.C0 = poignee.CFrame:ToObjectSpace(partie.CFrame)
			soudure.Parent = partie
		end
	end
	-- 2) réglages physiques
	for _, partie in parties do
		partie.Anchored = false
		partie.CanCollide = false
		partie.Massless = true
	end

	return finaliser(tool, definition)
end

function FabriqueOutil.creer(definition: Types.DefinitionOutil, objetDecor: Instance?): Tool?
	-- 1) modèle prêt dans ServerStorage.Outils.<id> (optionnel)
	local dossier = ServerStorage:FindFirstChild(NOM_DOSSIER_MODELES)
	if dossier and dossier:IsA("Folder") then
		local modele = dossier:FindFirstChild(definition.id)
		if modele and modele:IsA("Tool") then
			return finaliser(modele:Clone(), definition)
		end
	end

	-- 2) sinon conversion de l'objet du décor
	if not objetDecor then
		warn("FabriqueOutil : ni modèle ServerStorage.Outils." .. definition.id .. " ni objet du décor")
		return nil
	end
	return convertirDecor(definition, objetDecor)
end

return FabriqueOutil
