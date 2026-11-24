--!strict
--[[
	Rôle    : géométrie et rayons pour les outils : boîte englobante d'un objet,
	          distance à cette boîte, partie à afficher, test de visibilité.
	          Utilisé par le client ET le serveur avec exactement la même règle :
	          sinon le client afficherait des objets que le serveur refuserait.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local Players = game:GetService("Players")

local TRANSPARENCE_TRAVERSEE = 0.95  -- une partie au moins aussi transparente ne bloque pas la vue
local ESSAIS_MAX = 4                 -- nombre max de parties quasi invisibles traversées par point visé
local FACTEUR_HAUT = 0.9             -- le point « haut » est à 90 % de la demi-hauteur

local LigneDeVue = {}

-- Boîte de l'objet : (CFrame, taille). nil si l'objet n'a pas de géométrie.
function LigneDeVue.boite(objet: Instance): (CFrame?, Vector3?)
	if objet:IsA("BasePart") then
		return objet.CFrame, objet.Size
	end
	if objet:IsA("Model") then
		-- GetBoundingBox sur un modèle vide ne veut rien dire : on exige une BasePart
		if objet:FindFirstChildWhichIsA("BasePart", true) == nil then
			return nil, nil
		end
		return objet:GetBoundingBox()
	end
	return nil, nil
end

-- Centre de la boîte de l'objet
function LigneDeVue.pointCentral(objet: Instance): Vector3?
	local cframe, _taille = LigneDeVue.boite(objet)
	if cframe == nil then
		return nil
	end
	return cframe.Position
end

-- Partie à utiliser pour l'affichage : l'objet lui-même, sinon Handle, PrimaryPart,
-- sinon la première BasePart descendante
function LigneDeVue.partieAffichage(objet: Instance): BasePart?
	if objet:IsA("BasePart") then
		return objet
	end
	local poignee = objet:FindFirstChild("Handle")
	if poignee and poignee:IsA("BasePart") then
		return poignee
	end
	if objet:IsA("Model") and objet.PrimaryPart then
		return objet.PrimaryPart
	end
	return objet:FindFirstChildWhichIsA("BasePart", true)
end

-- Distance entre un point et la boîte de l'objet (0 si le point est dedans).
-- math.huge si l'objet n'a pas de géométrie.
function LigneDeVue.distance(objet: Instance, depuis: Vector3): number
	local cframe, taille = LigneDeVue.boite(objet)
	if cframe == nil or taille == nil then
		return math.huge
	end
	local local_ = cframe:PointToObjectSpace(depuis)
	local demi = taille / 2
	local pointProche = Vector3.new(
		math.clamp(local_.X, -demi.X, demi.X),
		math.clamp(local_.Y, -demi.Y, demi.Y),
		math.clamp(local_.Z, -demi.Z, demi.Z)
	)
	return (local_ - pointProche).Magnitude
end

-- Tire un rayon vers un point. Renvoie true si on voit l'objet (rien sur le chemin,
-- ou on touche l'objet lui-même). Les parties quasi invisibles sont traversées.
local function pointVisible(origine: Vector3, point: Vector3, objet: Instance, exclus: {Instance}): boolean
	local direction = point - origine
	if direction.Magnitude < 1e-3 then
		return true
	end

	local params = RaycastParams.new() -- neuf à chaque appel : AddToFilter ne pollue pas les autres tests
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = table.clone(exclus)
	params.IgnoreWater = true

	for _ = 1, ESSAIS_MAX do
		local resultat = workspace:Raycast(origine, direction, params)
		if resultat == nil then
			return true
		end
		local touche = resultat.Instance
		if touche == objet or touche:IsDescendantOf(objet) then
			return true
		end
		if touche:IsA("BasePart") and touche.Transparency >= TRANSPARENCE_TRAVERSEE then
			params:AddToFilter(touche) -- on traverse et on retire
		else
			return false -- vraiment bloqué
		end
	end
	return false
end

-- L'objet est-il visible depuis `origine` ? On vise le centre puis le haut de la boîte :
-- un seul point dégagé suffit.
function LigneDeVue.visibleDepuis(origine: Vector3, objet: Instance, exclus: {Instance}): boolean
	local cframe, taille = LigneDeVue.boite(objet)
	if cframe == nil or taille == nil then
		return false
	end
	local centre = cframe.Position
	local haut = centre + cframe.UpVector * (taille.Y / 2 * FACTEUR_HAUT)
	for _, point in { centre, haut } do
		if pointVisible(origine, point, objet, exclus) then
			return true
		end
	end
	return false
end

-- Personnages (Model) de tous les joueurs qui en ont un
function LigneDeVue.personnagesJoueurs(): {Instance}
	local liste: {Instance} = {}
	for _, joueur in Players:GetPlayers() do
		local personnage = joueur.Character
		if personnage then
			table.insert(liste, personnage)
		end
	end
	return liste
end

return LigneDeVue
