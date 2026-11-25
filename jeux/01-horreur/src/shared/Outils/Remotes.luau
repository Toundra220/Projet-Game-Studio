--!strict
--[[
	Rôle    : seul point de déclaration des RemoteEvent du système d'outils.
	          Serveur : trouve ou crée le dossier et les remotes.
	          Client  : attend qu'ils soient répliqués.
	          Contrats (le serveur valide tout, le client n'envoie que des intentions) :
	            DemanderRamassage  client -> serveur  (objet: Instance)
	            DemanderUtilisation client -> serveur ("debut", cible: Instance) ou ("arret")
	            RetourOutil        serveur -> client  (code: string, idOutil: string?)
	              codes : ramasse, achete, achat_propose, achat_annule, achat_indisponible,
	                      achat_non_configure (game pass pas encore créé),
	                      deja_possede, indisponible, trop_loin, pas_visible, mauvais_outil,
	                      utilisation_fini, utilisation_arretee
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NOM_DOSSIER = "RemotesOutils"
local NOM_RAMASSAGE = "DemanderRamassage"
local NOM_UTILISATION = "DemanderUtilisation"
local NOM_RETOUR = "RetourOutil"

export type RemotesOutils = {
	DemanderRamassage: RemoteEvent,
	DemanderUtilisation: RemoteEvent,
	RetourOutil: RemoteEvent,
}

local Remotes = {}

local enCache: RemotesOutils? = nil

-- Serveur : renvoie le RemoteEvent de ce nom, en le créant s'il n'existe pas
local function trouverOuCreerRemote(dossier: Folder, nom: string): RemoteEvent
	local existant = dossier:FindFirstChild(nom)
	if existant and existant:IsA("RemoteEvent") then
		return existant
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = nom
	remote.Parent = dossier -- Parent en dernier
	return remote
end

local function construireServeur(): RemotesOutils
	local dossier: Folder
	local existant = ReplicatedStorage:FindFirstChild(NOM_DOSSIER)
	if existant and existant:IsA("Folder") then
		dossier = existant
	else
		dossier = Instance.new("Folder")
		dossier.Name = NOM_DOSSIER
		dossier.Parent = ReplicatedStorage -- Parent en dernier
	end
	return {
		DemanderRamassage = trouverOuCreerRemote(dossier, NOM_RAMASSAGE),
		DemanderUtilisation = trouverOuCreerRemote(dossier, NOM_UTILISATION),
		RetourOutil = trouverOuCreerRemote(dossier, NOM_RETOUR),
	}
end

local function construireClient(): RemotesOutils
	local dossier = ReplicatedStorage:WaitForChild(NOM_DOSSIER)
	return {
		DemanderRamassage = dossier:WaitForChild(NOM_RAMASSAGE) :: RemoteEvent,
		DemanderUtilisation = dossier:WaitForChild(NOM_UTILISATION) :: RemoteEvent,
		RetourOutil = dossier:WaitForChild(NOM_RETOUR) :: RemoteEvent,
	}
end

-- Renvoie les remotes (créés une seule fois, puis gardés en mémoire)
function Remotes.obtenir(): RemotesOutils
	if enCache then
		return enCache
	end
	local remotes = if RunService:IsServer() then construireServeur() else construireClient()
	enCache = remotes
	return remotes
end

return Remotes
