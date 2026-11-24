--!strict
--[[
	Rôle    : ramassage / achat des outils côté joueur.
	          - cherche toutes les 0,1 s l'objet « Ramassable » regardé (DetecteurVisibilite) ;
	          - le met en surbrillance avec un texte (« [E] Ramasser le balai ») ;
	          - touche E / bouton X / bouton tactile (seulement quand une cible existe) ;
	          - affiche les messages renvoyés par le serveur (RetourOutil).
	          Le client ne décide rien : il demande, le serveur vérifie tout.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Definitions = require(Partage:WaitForChild("DefinitionsOutils"))
local Remotes = require(Partage:WaitForChild("Remotes"))

local DetecteurVisibilite = require(script.Parent:WaitForChild("DetecteurVisibilite"))
local AffichageCible = require(script.Parent:WaitForChild("AffichageCible"))
local Notification = require(script.Parent:WaitForChild("Notification"))
local MessagesOutils = require(script.Parent:WaitForChild("MessagesOutils"))

local Reglages = Definitions.Reglages

local NOM_ACTION = "RamasserOutil"
local DELAI_ANTI_REPETITION = 0.4 -- secondes entre deux demandes

local remotes = Remotes.obtenir()

-- Détecteur et affichage sont créés ici puis utilisés seulement par leur interface
local detecteur = DetecteurVisibilite.nouveau({
	tag = Reglages.TAG_RAMASSABLE,
	portee = Reglages.PORTEE_RAMASSAGE,
	demiAngle = Reglages.DEMI_ANGLE_CIBLAGE,
	filtre = function(objet: Instance): boolean
		local id = objet:GetAttribute(Reglages.ATTRIBUT_OUTIL)
		if Definitions.obtenir(id) == nil then
			return false
		end
		-- inutile de proposer un outil que le joueur a déjà (sac ou main)
		local joueur = Players.LocalPlayer
		local sac = joueur:FindFirstChildOfClass("Backpack")
		for _, conteneur in { sac, joueur.Character } do
			if conteneur then
				for _, enfant in conteneur:GetChildren() do
					if enfant:IsA("Tool") and enfant:GetAttribute(Reglages.ATTRIBUT_OUTIL) == id then
						return false
					end
				end
			end
		end
		return true
	end,
})
local affichage = AffichageCible.nouveau()

local cibleActuelle: Instance? = nil
local texteActuel = ""
local actionLiee = false
local derniereDemande = 0

-- Touche affichée selon le dernier périphérique utilisé
local function nomTouche(): string
	local dernier = UserInputService:GetLastInputType()
	if dernier == Enum.UserInputType.Gamepad1 or dernier == Enum.UserInputType.Gamepad2 then
		return "[X]"
	elseif dernier == Enum.UserInputType.Touch then
		return "Toucher"
	end
	return "[E]"
end

local function construireTexte(cible: Instance): string
	local definition = Definitions.obtenir(cible:GetAttribute(Reglages.ATTRIBUT_OUTIL))
	if not definition then
		return ""
	end
	local verbe = if definition.payant then "Acheter " else "Ramasser "
	local suffixe = if definition.payant then " (Robux)" else ""
	return nomTouche() .. " " .. verbe .. definition.article .. suffixe
end

local function gererAction(_nom: string, etat: Enum.UserInputState, _entree: InputObject): Enum.ContextActionResult
	if etat ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local cible = cibleActuelle
	if not cible then
		return Enum.ContextActionResult.Pass
	end
	local maintenant = os.clock()
	if maintenant - derniereDemande < DELAI_ANTI_REPETITION then
		return Enum.ContextActionResult.Sink
	end
	derniereDemande = maintenant
	remotes.DemanderRamassage:FireServer(cible) -- le serveur vérifie tout
	return Enum.ContextActionResult.Sink
end

local function lierAction()
	if actionLiee then
		return
	end
	actionLiee = true
	ContextActionService:BindAction(NOM_ACTION, gererAction, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle(NOM_ACTION, "E")
end

local function delierAction()
	if not actionLiee then
		return
	end
	actionLiee = false
	ContextActionService:UnbindAction(NOM_ACTION)
end

-- Boucle de détection : met à jour l'affichage seulement quand quelque chose change
task.spawn(function()
	while true do
		local cible = detecteur.chercher()
		local texte = if cible then construireTexte(cible) else ""
		if cible and texte == "" then
			cible = nil
		end

		if cible ~= cibleActuelle or texte ~= texteActuel then
			if cible then
				affichage.afficher(cible, texte)
				lierAction()
			else
				affichage.masquer()
				delierAction()
			end
			cibleActuelle = cible
			texteActuel = texte
		end
		task.wait(Reglages.PERIODE_DETECTION)
	end
end)

-- Seul écouteur qui affiche les messages du serveur
remotes.RetourOutil.OnClientEvent:Connect(function(code: unknown, idOutil: unknown)
	if type(code) ~= "string" then
		return
	end
	local definition = Definitions.obtenir(idOutil) -- renvoie nil si ce n'est pas un texte connu
	Notification.afficher(MessagesOutils.texte(code, definition))
end)
