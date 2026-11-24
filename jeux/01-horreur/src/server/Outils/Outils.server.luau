--!strict
--[[
	Rôle    : racine de composition des outils côté serveur. C'est ici (et seulement ici)
	          qu'on choisit les implémentations et qu'on les branche (injection de dépendances).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Remotes = require(Partage:WaitForChild("Remotes"))

local FabriqueOutil = require(script.Parent:WaitForChild("FabriqueOutil"))
local ValidationServeur = require(script.Parent:WaitForChild("ValidationServeur"))
local PaiementRobux = require(script.Parent:WaitForChild("PaiementRobux"))
local ServiceRamassage = require(script.Parent:WaitForChild("ServiceRamassage"))
local EvenementsServeur = require(script.Parent:WaitForChild("EvenementsServeur"))
local ServiceUtilisation = require(script.Parent:WaitForChild("ServiceUtilisation"))
local Nettoyage = require(script.Parent:WaitForChild("Utilisations"):WaitForChild("Nettoyage"))

local remotes = Remotes.obtenir()

-- Seul endroit où l'on choisit le mode de paiement (DIP) : pour changer de mode
-- (autre moyen de paiement, gratuit pour les tests...), on remplace seulement cette ligne.
local paiement = PaiementRobux.nouveau()

ServiceRamassage.demarrer({
	remotes = remotes,
	paiement = paiement,
	fabrique = FabriqueOutil,
	validation = ValidationServeur,
})

local evenements = EvenementsServeur.obtenir()

-- Un nouvel usage d'outil = une stratégie dans Utilisations/ + une ligne ici (OCP).
-- La clé est le champ « utilisation » de la définition de l'outil.
ServiceUtilisation.demarrer({
	remotes = remotes,
	validation = ValidationServeur,
	strategies = {
		Nettoyage = Nettoyage.nouveau(evenements),
	},
})
