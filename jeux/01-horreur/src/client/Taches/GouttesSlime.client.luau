--!strict
--[[
	Rôle    : fait couler le slime des taches murales. Pour chaque tache « Mur » proche du joueur
	          et pas encore nettoyée, des gouttes se forment au bas des coulures (les parties
	          « Bout... » du modèle), tombent jusqu'au sol (point trouvé par un raycast) et font
	          une flaque qui disparaît (voir AnimateurGouttes). Rythme aléatoire, lent ; moins de
	          gouttes quand Progression monte ; plus rien dès que Nettoye vaut vrai.
	          Purement visuel et local : aucune communication réseau, parties sans collision.
	          Streaming : on suit le tag « Nettoyable » ; une tache qui arrive (ou repart) du
	          streaming est ajoutée (ou retirée) du suivi, sans erreur si ses parties manquent.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Partage = ReplicatedStorage:WaitForChild("Shared")
local Reglages = require(Partage:WaitForChild("Taches"):WaitForChild("ReglagesGouttes"))
local ReglagesTaches = require(Partage:WaitForChild("Taches"):WaitForChild("ReglagesTaches"))
local DefinitionsOutils = require(Partage:WaitForChild("Outils"):WaitForChild("DefinitionsOutils"))
local AnimateurGouttes = require(script.Parent:WaitForChild("AnimateurGouttes"))

local Outils = DefinitionsOutils.Reglages
local joueur = Players.LocalPlayer
local rng = Random.new()

type Suivi = {
	modele: Model,
	prochain: number,              -- os.clock() de la prochaine tentative de goutte
	proche: boolean,               -- la tache était à portée à la dernière vérification
	normale: Vector3?,             -- direction mur -> pièce (calculée au premier besoin)
	sourcesOccupees: { [BasePart]: number }, -- source -> os.clock() à partir duquel elle peut servir de nouveau
}

local dossierLocal = Instance.new("Folder")
dossierLocal.Name = "GouttesLocales" -- créé côté client seulement : le serveur ne le voit pas
dossierLocal.Parent = workspace

local animateur = AnimateurGouttes.nouveau(Reglages, dossierLocal)
local suivis: { [Instance]: Suivi } = {}

local paramsRayon = RaycastParams.new()
paramsRayon.FilterType = Enum.RaycastFilterType.Exclude
paramsRayon.RespectCanCollide = false -- les taches, parties sans collision, sont déjà exclues par le filtre

local function intervalleAleatoire(progression: number): number
	local base = Reglages.INTERVALLE_MIN + (Reglages.INTERVALLE_MAX - Reglages.INTERVALLE_MIN) * rng:NextNumber()
	local facteur = math.max(1 - progression * Reglages.REDUCTION_PROGRESSION, 0.05)
	return base / facteur
end

local function progressionDe(modele: Model): number
	local valeur = modele:GetAttribute(Outils.ATTRIBUT_PROGRESSION)
	if type(valeur) ~= "number" or valeur ~= valeur then
		return 0
	end
	return math.clamp(valeur, 0, 1)
end

local function estNettoyee(modele: Model): boolean
	return modele:GetAttribute(Outils.ATTRIBUT_NETTOYE) == true
end

-- Direction du mur vers la pièce : du Corps (le plan du mur) vers le centre de la masse de slime
local function calculerNormale(modele: Model): Vector3?
	local corps = modele.PrimaryPart
	if corps == nil then
		return nil
	end
	local boite = modele:GetBoundingBox()
	local axe = corps.CFrame.LookVector
	local signe = if (boite.Position - corps.Position):Dot(axe) >= 0 then 1 else -1
	return axe * signe
end

-- Parties « Bout... » encore dans le modèle (elles peuvent manquer si le modèle est en cours de streaming)
local function choisirSource(suivi: Suivi, maintenant: number): BasePart?
	local candidates: { BasePart } = {}
	for _, enfant in suivi.modele:GetChildren() do
		if enfant:IsA("BasePart") and string.sub(enfant.Name, 1, #Reglages.PREFIXE_SOURCE) == Reglages.PREFIXE_SOURCE then
			local libreA = suivi.sourcesOccupees[enfant]
			if libreA == nil or maintenant >= libreA then
				table.insert(candidates, enfant)
				if #candidates >= Reglages.SOURCES_MAX_PAR_TACHE then
					break
				end
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Point le plus bas de la partie, avancé devant le mur
local function pointDeGoutte(partie: BasePart, normale: Vector3): Vector3
	local cf = partie.CFrame
	local taille = partie.Size
	local demiHauteur = 0.5 * (math.abs(cf.XVector.Y) * taille.X + math.abs(cf.YVector.Y) * taille.Y + math.abs(cf.ZVector.Y) * taille.Z)
	return partie.Position - Vector3.new(0, demiHauteur, 0) + normale * Reglages.DECALAGE_NORMALE
end

-- Hauteur du sol sous le point, ou nil s'il n'y en a pas assez bas (trop près, trop loin, pente raide)
local function trouverSol(point: Vector3): number?
	local exclus: { Instance } = { dossierLocal }
	local taches = workspace:FindFirstChild(ReglagesTaches.NOM_DOSSIER)
	if taches then
		table.insert(exclus, taches)
	end
	if joueur.Character then
		table.insert(exclus, joueur.Character)
	end
	paramsRayon.FilterDescendantsInstances = exclus
	local resultat = workspace:Raycast(point, Vector3.new(0, -Reglages.PORTEE_RAYON_SOL, 0), paramsRayon)
	if resultat == nil or resultat.Normal.Y < 0.5 then
		return nil
	end
	if point.Y - resultat.Position.Y < Reglages.HAUTEUR_CHUTE_MIN then
		return nil
	end
	return resultat.Position.Y
end

local function essayerGoutte(suivi: Suivi, maintenant: number)
	if animateur.nombreDe(suivi.modele) >= Reglages.GOUTTES_SIMULTANEES_PAR_TACHE then
		return
	end
	if suivi.normale == nil then
		suivi.normale = calculerNormale(suivi.modele)
		if suivi.normale == nil then
			return -- pas de PrimaryPart (encore ?) : on réessaiera
		end
	end
	local source = choisirSource(suivi, maintenant)
	if source == nil then
		return
	end
	-- la source est réservée même si la goutte échoue : évite de retester sans cesse un bout trop près du sol
	suivi.sourcesOccupees[source] = maintenant + Reglages.FORMATION_DUREE_MAX + 3
	local point = pointDeGoutte(source, suivi.normale :: Vector3)
	local solY = trouverSol(point)
	if solY == nil then
		return
	end
	animateur.lancerGoutte(suivi.modele, point, solY)
end

local function suivre(instance: Instance)
	if suivis[instance] ~= nil or not instance:IsA("Model") then
		return
	end
	if instance:GetAttribute(ReglagesTaches.ATTRIBUT_TYPE) ~= Reglages.TYPE_TACHE or estNettoyee(instance) then
		return
	end
	suivis[instance] = {
		modele = instance,
		prochain = os.clock() + intervalleAleatoire(0),
		proche = false,
		normale = nil,
		sourcesOccupees = {},
	}
end

local function oublier(instance: Instance)
	if suivis[instance] ~= nil then
		suivis[instance] = nil
		animateur.abandonner(instance)
	end
end

-- Le tag est posé par le serveur, parfois après l'arrivée de l'objet : on réessaie un instant plus tard
local function surNouveauTag(instance: Instance)
	task.defer(suivre, instance)
end

CollectionService:GetInstanceAddedSignal(Outils.TAG_NETTOYABLE):Connect(surNouveauTag)
CollectionService:GetInstanceRemovedSignal(Outils.TAG_NETTOYABLE):Connect(oublier) -- nettoyée (tag retiré) ou sortie du streaming
for _, instance in CollectionService:GetTagged(Outils.TAG_NETTOYABLE) do
	surNouveauTag(instance)
end

-- Sécurité : une tache supprimée du jeu sans que le tag soit retiré avant
workspace.DescendantRemoving:Connect(function(descendant: Instance)
	if suivis[descendant] ~= nil then
		oublier(descendant)
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	if next(suivis) == nil and animateur.nombreTotal() == 0 then
		return
	end
	local camera = workspace.CurrentCamera
	local maintenant = os.clock()

	for instance, suivi in suivis do
		local modele = suivi.modele
		local corps = modele.PrimaryPart
		if estNettoyee(modele) then
			oublier(instance) -- modifier la table pendant le parcours est permis pour retirer une entrée
		elseif corps ~= nil and camera ~= nil then
			local proche = (corps.Position - camera.CFrame.Position).Magnitude <= Reglages.DISTANCE_MAX
			if not proche then
				if suivi.proche then
					suivi.proche = false
					animateur.abandonner(instance)
				end
			else
				if not suivi.proche then
					suivi.proche = true
					suivi.prochain = maintenant + intervalleAleatoire(progressionDe(modele)) -- pas de rafale en arrivant
				end
				if maintenant >= suivi.prochain then
					suivi.prochain = maintenant + intervalleAleatoire(progressionDe(modele))
					essayerGoutte(suivi, maintenant)
				end
			end
		end
	end

	animateur.mettreAJour(dt)
end)

script.Destroying:Connect(function()
	animateur.detruire()
	dossierLocal:Destroy()
end)
