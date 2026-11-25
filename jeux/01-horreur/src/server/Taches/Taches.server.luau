--!strict
--[[
	Rôle    : prépare les taches de ménage au démarrage du serveur.
	          Pour chaque objet de Workspace.Taches portant l'attribut TypeTache (« Sol » ou « Mur ») :
	          - pose le tag Nettoyable (les outils ne ciblent que des objets taggés),
	          - pose DureeNettoyage et FacteurBruit d'après ReglagesTaches (une seule source de chiffres),
	          - repart d'une tache propre (retire Progression et Nettoye),
	          - force « sans collision » : le joueur et le monstre passent à travers, rien ne bloque le chemin.
	          Compte les taches (attributs Total et Restantes sur le dossier) et écrit dans la Sortie
	          chaque tache nettoyée. Aucune règle de jeu ici : le nettoyage est fait par les outils
	          (Outils/Utilisations/Nettoyage), le bruit est entendu par MonstreIA.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared")
local DefinitionsOutils = require(Partage:WaitForChild("Outils"):WaitForChild("DefinitionsOutils"))
local ReglagesTaches = require(Partage:WaitForChild("Taches"):WaitForChild("ReglagesTaches"))
local EvenementsServeur = require(script.Parent.Parent:WaitForChild("Outils"):WaitForChild("EvenementsServeur"))

local Outils = DefinitionsOutils.Reglages

local dossier = workspace:WaitForChild(ReglagesTaches.NOM_DOSSIER, 15)
if not dossier then
	warn("Taches : Workspace." .. ReglagesTaches.NOM_DOSSIER .. " est introuvable, aucune tache préparée")
	return
end

local actives: { [Instance]: string } = {} -- taches pas encore nettoyées, avec leur type
local total = 0
local restantes = 0

local function publierCompteurs()
	dossier:SetAttribute(ReglagesTaches.ATTRIBUT_TOTAL, total)
	dossier:SetAttribute(ReglagesTaches.ATTRIBUT_RESTANTES, restantes)
end

-- Toutes les parties de l'objet (lui-même s'il en est une)
local function lesParties(objet: Instance): { BasePart }
	local parties: { BasePart } = {}
	if objet:IsA("BasePart") then
		table.insert(parties, objet)
	end
	for _, descendant in objet:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parties, descendant)
		end
	end
	return parties
end

local function preparer(objet: Instance)
	local nomType = objet:GetAttribute(ReglagesTaches.ATTRIBUT_TYPE)
	if nomType == nil or actives[objet] ~= nil then
		return -- pas une tache, ou déjà prête
	end

	local typeTache = ReglagesTaches.obtenirType(nomType)
	if typeTache == nil then
		warn(("Taches : %s a un TypeTache inconnu (%s), ignorée"):format(objet:GetFullName(), tostring(nomType)))
		return
	end
	if not (objet:IsA("Model") or objet:IsA("BasePart")) then
		warn(("Taches : %s doit être un Model ou une BasePart, ignorée"):format(objet:GetFullName()))
		return
	end
	local parties = lesParties(objet)
	if #parties == 0 then
		warn(("Taches : %s n'a aucune partie visible, ignorée"):format(objet:GetFullName()))
		return
	end
	if objet:IsA("Model") and objet.PrimaryPart == nil then
		-- GetBoundingBox suivrait l'orientation de la première partie venue : centre et portée faussés
		warn(("Taches : %s n'a pas de PrimaryPart (une partie à plat, sans inclinaison)"):format(objet:GetFullName()))
	end

	for _, partie in parties do
		partie.Anchored = true
		partie.CanCollide = false -- ni obstacle pour le joueur, ni pour le chemin du monstre
		partie.CanTouch = false
		partie.CanQuery = true    -- les rayons de visée des outils doivent la toucher (LigneDeVue)
	end

	objet:SetAttribute(Outils.ATTRIBUT_DUREE, typeTache.duree * ReglagesTaches.multiplicateurDe(objet))
	objet:SetAttribute(Outils.ATTRIBUT_FACTEUR_BRUIT, typeTache.facteurBruit)
	objet:SetAttribute(Outils.ATTRIBUT_NETTOYE, nil)
	objet:SetAttribute(Outils.ATTRIBUT_PROGRESSION, nil)
	CollectionService:AddTag(objet, Outils.TAG_NETTOYABLE)

	actives[objet] = tostring(nomType)
	total += 1
	restantes += 1
	publierCompteurs()
end

for _, descendant in dossier:GetDescendants() do
	preparer(descendant)
end

-- Une tache ajoutée après le démarrage est préparée aussi (on attend la fin de sa création : task.defer)
dossier.DescendantAdded:Connect(function(descendant: Instance)
	task.defer(preparer, descendant)
end)

-- Une tache détruite avant d'être nettoyée ne compte plus
dossier.DescendantRemoving:Connect(function(descendant: Instance)
	if actives[descendant] ~= nil then
		actives[descendant] = nil
		total -= 1
		restantes -= 1
		publierCompteurs()
	end
end)

-- Une tache nettoyée (le serveur a décidé : voir Nettoyage.finir) : compteur et trace dans la Sortie
EvenementsServeur.obtenir().termine.Event:Connect(function(joueur: unknown, cible: unknown, idOutil: unknown)
	if typeof(cible) ~= "Instance" then
		return
	end
	local tache = cible :: Instance
	if actives[tache] == nil then
		return
	end
	actives[tache] = nil
	restantes -= 1
	publierCompteurs()
	local nomJoueur = if typeof(joueur) == "Instance" then (joueur :: Instance).Name else "?"
	print(("[Taches] %s nettoyée par %s (%s) : %d restante(s) sur %d"):format(
		tache:GetFullName(), nomJoueur, tostring(idOutil), restantes, total))
	if restantes == 0 then
		print("[Taches] toutes les taches sont nettoyées")
	end
end)

-- Résumé au démarrage
local parType: { [string]: number } = {}
for _, nomType in actives do
	parType[nomType] = (parType[nomType] or 0) + 1
end
local detail: { string } = {}
for nomType, nombre in parType do
	table.insert(detail, ("%s %d"):format(nomType, nombre))
end
table.sort(detail)
print(("[Taches] %d taches prêtes (%s)"):format(total, table.concat(detail, ", ")))
