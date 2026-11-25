--!strict
--[[
	Rôle    : retours visuels du nettoyage, chez chaque joueur (purement visuel, aucun réseau) :
	          - pendant le nettoyage : petites bouffées de poussière (tache au sol) ou
	            éclaboussures vertes (slime mural) sur la tache ;
	          - la tache pâlit au fur et à mesure de l'attribut Progression (posé par le serveur) ;
	          - à la fin (attribut Nettoye) : une bouffée plus grosse, puis le fondu du serveur.
	          Fonctionne pour toute tache taguée Nettoyable, quel que soit le joueur qui nettoie.
	          Particules avec les textures intégrées de Roblox (rbxasset://, pas d'ID d'asset).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Definitions = require(Partage:WaitForChild("DefinitionsOutils") :: ModuleScript)
local LigneDeVue = require(Partage:WaitForChild("LigneDeVue") :: ModuleScript)

local Reglages = Definitions.Reglages

-- Tous les chiffres de l'effet (règle 9 de Regles-de-prompt)
local R = table.freeze({
	PALISSEMENT_MAX = 0.55,     -- à 100 % de progression, la tache a perdu 55 % de son opacité...
	TRANSPARENCE_PLAFOND = 0.9, -- ... sans jamais dépasser 0.9 (au delà, LigneDeVue la traverserait)
	PERIODE_EMISSION = 0.12,    -- secondes minimum entre deux petites bouffées sur la même tache
	PARTICULES_PAR_BOUFFEE = 3,
	PARTICULES_FIN = 22,        -- bouffée de fin de nettoyage
	DECALAGE_MUR = 0.4,         -- studs : les éclaboussures partent un peu devant le mur
	TEXTURE = "rbxasset://textures/particles/smoke_main.dds", -- texture intégrée au client Roblox
	COULEUR_POUSSIERE = Color3.fromRGB(95, 85, 72),
	COULEUR_SLIME = Color3.fromRGB(88, 214, 54),
})

local dossierLocal = Instance.new("Folder")
dossierLocal.Name = "EffetsNettoyageLocaux"
dossierLocal.Parent = workspace

type Etat = {
	emetteur: ParticleEmitter,
	support: BasePart,
	opacites: { [Instance]: number }, -- transparence d'origine de chaque partie / decal
	derniereEmission: number,
	connexions: { RBXScriptConnection },
}

local etats: { [Instance]: Etat } = {}

local function estMur(tache: Instance): boolean
	return tache:GetAttribute(Reglages.ATTRIBUT_TYPE_TACHE) == "Mur"
end

-- Position et orientation des particules : au sol elles montent, au mur elles sortent du mur
-- (axe le plus fin de la boîte, côté caméra).
local function placement(tache: Instance): CFrame?
	local cadre, taille = LigneDeVue.boite(tache)
	if not cadre or not taille then
		return nil
	end
	if not estMur(tache) then
		return CFrame.lookAt(cadre.Position, cadre.Position + Vector3.yAxis)
	end
	local axes = { cadre.RightVector, cadre.UpVector, cadre.LookVector }
	local dims = { taille.X, taille.Y, taille.Z }
	local indice = 1
	for i = 2, 3 do
		if dims[i] < dims[indice] then
			indice = i
		end
	end
	local normale = axes[indice]
	local camera = workspace.CurrentCamera
	if camera and normale:Dot(camera.CFrame.Position - cadre.Position) < 0 then
		normale = -normale
	end
	local depart = cadre.Position + normale * R.DECALAGE_MUR
	return CFrame.lookAt(depart, depart + normale)
end

local function creerEmetteur(tache: Instance, cadre: CFrame): (BasePart, ParticleEmitter)
	local support = Instance.new("Part")
	support.Name = "Support_" .. tache.Name
	support.Size = Vector3.new(0.2, 0.2, 0.2)
	support.Transparency = 1
	support.Anchored = true
	support.CanCollide = false
	support.CanQuery = false
	support.CanTouch = false
	support.CFrame = cadre
	support.Parent = dossierLocal

	local emetteur = Instance.new("ParticleEmitter")
	emetteur.Enabled = false
	emetteur.Texture = R.TEXTURE
	emetteur.EmissionDirection = Enum.NormalId.Front -- le long de la normale choisie
	emetteur.LockedToPart = false
	if estMur(tache) then
		-- éclaboussures de slime : petites, rapides, retombent
		emetteur.Color = ColorSequence.new(R.COULEUR_SLIME)
		emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
		emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		emetteur.Lifetime = NumberRange.new(0.35, 0.7)
		emetteur.Speed = NumberRange.new(4, 7)
		emetteur.SpreadAngle = Vector2.new(35, 35)
		emetteur.Acceleration = Vector3.new(0, -30, 0)
		emetteur.Drag = 1
	else
		-- poussière : grosse, lente, qui flotte et se dissipe
		emetteur.Color = ColorSequence.new(R.COULEUR_POUSSIERE)
		emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
		emetteur.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		emetteur.Lifetime = NumberRange.new(0.5, 1.0)
		emetteur.Speed = NumberRange.new(1.5, 3.5)
		emetteur.SpreadAngle = Vector2.new(60, 60)
		emetteur.Acceleration = Vector3.new(0, 1.5, 0)
		emetteur.Drag = 3
		emetteur.RotSpeed = NumberRange.new(-40, 40)
	end
	emetteur.Parent = support
	return support, emetteur
end

-- La tache pâlit selon sa progression (le serveur fera ensuite le fondu final jusqu'à 1)
local function palir(etat: Etat, tache: Instance, progression: number)
	local elements: { Instance } = { tache }
	for _, d in tache:GetDescendants() do
		table.insert(elements, d)
	end
	for _, element in elements do
		if element:IsA("BasePart") or element:IsA("Decal") or element:IsA("Texture") then
			local partie = element :: any
			local origine = etat.opacites[element]
			if origine == nil then
				origine = partie.Transparency :: number
				etat.opacites[element] = origine
			end
			if origine < 1 then
				local cible = origine + (1 - origine) * R.PALISSEMENT_MAX * progression
				partie.Transparency = math.min(cible, math.max(origine, R.TRANSPARENCE_PLAFOND))
			end
		end
	end
end

local function oublier(tache: Instance)
	local etat = etats[tache]
	if not etat then
		return
	end
	etats[tache] = nil
	for _, c in etat.connexions do
		c:Disconnect()
	end
	-- laisse finir les dernières particules avant de détruire le support
	task.delay(1.2, function()
		etat.support:Destroy()
	end)
end

local function suivre(tache: Instance)
	if etats[tache] or tache:GetAttribute(Reglages.ATTRIBUT_NETTOYE) == true then
		return
	end
	local cadre = placement(tache)
	if not cadre then
		return
	end
	local support, emetteur = creerEmetteur(tache, cadre)
	local etat: Etat = {
		emetteur = emetteur,
		support = support,
		opacites = {},
		derniereEmission = -math.huge,
		connexions = {},
	}
	etats[tache] = etat

	local function surProgression()
		local p = tache:GetAttribute(Reglages.ATTRIBUT_PROGRESSION)
		if type(p) ~= "number" or tache:GetAttribute(Reglages.ATTRIBUT_NETTOYE) == true then
			return
		end
		palir(etat, tache, math.clamp(p, 0, 1))
		local maintenant = os.clock()
		if p > 0 and maintenant - etat.derniereEmission >= R.PERIODE_EMISSION then
			etat.derniereEmission = maintenant
			-- au mur, la normale dépend de la caméra : on la recalcule (léger)
			local nouveau = placement(tache)
			if nouveau then
				support.CFrame = nouveau
			end
			emetteur:Emit(R.PARTICULES_PAR_BOUFFEE)
		end
	end

	table.insert(etat.connexions, tache:GetAttributeChangedSignal(Reglages.ATTRIBUT_PROGRESSION):Connect(surProgression))
	table.insert(etat.connexions, tache:GetAttributeChangedSignal(Reglages.ATTRIBUT_NETTOYE):Connect(function()
		if tache:GetAttribute(Reglages.ATTRIBUT_NETTOYE) == true then
			emetteur:Emit(R.PARTICULES_FIN)
			oublier(tache)
		end
	end))
	-- sortie du streaming ou destruction
	table.insert(etat.connexions, tache.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			oublier(tache)
		end
	end))

	-- progression déjà entamée (par un autre joueur, ou avant notre arrivée)
	surProgression()
end

for _, tache in CollectionService:GetTagged(Reglages.TAG_NETTOYABLE) do
	task.spawn(suivre, tache)
end
CollectionService:GetInstanceAddedSignal(Reglages.TAG_NETTOYABLE):Connect(suivre)
