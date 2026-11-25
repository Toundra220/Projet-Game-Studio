--!strict
--[[
	Rôle    : mode de TEST dans Studio : rend les outils payants (aspirateur) gratuits, pour tester
	          sans créer le game pass ni payer. Enveloppe un autre Paiement (PaiementRobux) :
	          seul « possede » change ; tout le reste est délégué tel quel.
	          Activation : dans Studio, mettre l'attribut booléen « OutilsPayantsGratuitsEnStudio »
	          à true sur ServerScriptService (Propriétés > Attributs), puis lancer Play.
	          - désactivé par défaut (attribut absent ou false) ;
	          - JAMAIS actif en jeu publié : RunService:IsStudio() est vérifié à chaque appel,
	            et Outils.server n'enveloppe le paiement que dans Studio.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-26
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))

local PaiementStudio = {}

PaiementStudio.ATTRIBUT = "OutilsPayantsGratuitsEnStudio"

-- Le mode test est-il actif MAINTENANT ? (relu à chaque appel : on peut le changer en cours de test)
function PaiementStudio.estActif(): boolean
	return RunService:IsStudio() and ServerScriptService:GetAttribute(PaiementStudio.ATTRIBUT) == true
end

function PaiementStudio.envelopper(paiement: Types.Paiement): Types.Paiement
	local signale = false

	local function possede(joueur: Player, definition: Types.DefinitionOutil): boolean
		if PaiementStudio.estActif() then
			if not signale then
				signale = true
				warn("PaiementStudio : MODE TEST STUDIO, outils payants gratuits (attribut "
					.. PaiementStudio.ATTRIBUT .. " de ServerScriptService). Sans effet en jeu publié.")
			end
			return true
		end
		return paiement.possede(joueur, definition)
	end

	return {
		nom = paiement.nom .. " + test Studio",
		possede = possede,
		proposerAchat = paiement.proposerAchat,
		surAchatConfirme = paiement.surAchatConfirme,
		surAchatAnnule = paiement.surAchatAnnule,
	}
end

return PaiementStudio
