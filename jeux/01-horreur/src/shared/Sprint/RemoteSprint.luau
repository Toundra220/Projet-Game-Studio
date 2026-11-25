--!strict
--[[
	Rôle    : seul point de déclaration du RemoteEvent du sprint.
	          Serveur : trouve ou crée le dossier et le remote. Client : attend qu'ils soient répliqués.
	          Contrat (le serveur valide tout, le client n'envoie qu'une intention) :
	            DemanderCourse  client -> serveur  (veutCourir: boolean)
	          Le serveur ne répond pas par un remote : l'endurance et l'état de course sont des
	          attributs du Player (voir ReglagesSprint), répliqués tout seuls.
Origine : ÉCRIT PAR CLAUDE (même motif que Outils/Remotes)
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Reglages = require(script.Parent:WaitForChild("ReglagesSprint"))

local RemoteSprint = {}

local enCache: RemoteEvent? = nil

local function construireServeur(): RemoteEvent
	local dossier = ReplicatedStorage:FindFirstChild(Reglages.NOM_DOSSIER_REMOTES)
	if not dossier or not dossier:IsA("Folder") then
		local nouveau = Instance.new("Folder")
		nouveau.Name = Reglages.NOM_DOSSIER_REMOTES
		nouveau.Parent = ReplicatedStorage -- Parent en dernier
		dossier = nouveau
	end
	local existant = dossier:FindFirstChild(Reglages.NOM_REMOTE_COURSE)
	if existant and existant:IsA("RemoteEvent") then
		return existant
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = Reglages.NOM_REMOTE_COURSE
	remote.Parent = dossier -- Parent en dernier
	return remote
end

local function construireClient(): RemoteEvent
	local dossier = ReplicatedStorage:WaitForChild(Reglages.NOM_DOSSIER_REMOTES)
	return dossier:WaitForChild(Reglages.NOM_REMOTE_COURSE) :: RemoteEvent
end

function RemoteSprint.obtenir(): RemoteEvent
	if enCache then
		return enCache
	end
	local remote = if RunService:IsServer() then construireServeur() else construireClient()
	enCache = remote
	return remote
end

return RemoteSprint
