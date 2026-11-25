--!strict
--[[
	Rôle    : calcule CÔTÉ SERVEUR le niveau de bruit de chaque joueur et le publie.
	          Le serveur observe lui-même : vitesse de la racine et sol (marche, course, sauts),
	          outil en main en train de nettoyer (attribut EnUtilisation, posé par le serveur),
	          ramassage d'un objet (BindableEvent OutilDonne de ServerStorage, tiré par le serveur).
	          Aucun RemoteEvent : un client ne peut ni inventer ni taire un bruit.
	          - publie le niveau lissé dans l'attribut NiveauBruit du Player (lu par Client/Bruit,
	            qui ne fait que l'afficher) ;
	          - prévient le monstre des bruits de corps (stades 1 à 3) avec le stade BRUT, au plus
	            toutes les PERIODE_EMISSION : MonstreBruit:Fire(position, nil, joueur, stade).
	            Le monstre choisit lui-même la portée d'écoute du stade (Server/Monstre/Reglages).
	            Le nettoyage (stade 4) est déjà signalé par l'outil (Outils/Utilisations/Nettoyage) :
	            pas de doublon ici.
	          Cycle de vie : un état neuf à chaque personnage, rien ne reste après PlayerRemoving.
	          Dépendances reçues par ctx (inversion de dépendance, skill solid-luau).
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local Players = game:GetService("Players")

local CalculNiveau = require(script.Parent:WaitForChild("CalculNiveau"))

export type Contexte = {
	reglages: any,                       -- Shared/Bruit/ReglagesBruit
	evenementBruit: BindableEvent,       -- ServerStorage.MonstreBruit
	evenementOutil: BindableEvent?,      -- ServerStorage.OutilDonne (ramassage)
	attributEnUtilisation: string,       -- nom de l'attribut posé sur l'outil pendant un nettoyage
	horloge: (() -> number)?,            -- os.clock par défaut
}

export type ServiceBruit = {
	niveauDe: (joueur: Player) -> number, -- niveau publié (lecture seule, tests)
	arreter: () -> (),
}

type Fiche = {
	etat: CalculNiveau.Etat,
	actionJusqua: number,
	derniereEmission: number,
	dernierStadeEmis: number,
	publie: number,
}

local ServiceBruit = {}

function ServiceBruit.demarrer(ctx: Contexte): ServiceBruit
	local R = ctx.reglages
	local horloge = ctx.horloge or os.clock
	local fiches: { [Player]: Fiche } = {}
	local connexions: { RBXScriptConnection } = {}
	local actif = true

	local function nouvelleFiche(): Fiche
		return {
			etat = CalculNiveau.nouvelEtat(),
			actionJusqua = -math.huge,
			derniereEmission = -math.huge,
			dernierStadeEmis = 0,
			publie = -1,
		}
	end

	local function publier(joueur: Player, fiche: Fiche, niveau: number)
		if fiche.publie ~= niveau then
			fiche.publie = niveau
			joueur:SetAttribute(R.ATTRIBUT_NIVEAU, niveau)
		end
	end

	local function ajouter(joueur: Player)
		if fiches[joueur] then
			return
		end
		local fiche = nouvelleFiche()
		fiches[joueur] = fiche
		publier(joueur, fiche, 0)
		-- nouveau personnage : silence, rien ne reste du précédent
		table.insert(connexions, joueur.CharacterAdded:Connect(function()
			local f = nouvelleFiche()
			fiches[joueur] = f
			publier(joueur, f, 0)
		end))
	end

	table.insert(connexions, Players.PlayerAdded:Connect(ajouter))
	for _, joueur in Players:GetPlayers() do
		ajouter(joueur)
	end
	table.insert(connexions, Players.PlayerRemoving:Connect(function(joueur)
		fiches[joueur] = nil
	end))

	-- Ramassage : l'événement vient du serveur (ServiceRamassage), jamais du client
	if ctx.evenementOutil then
		table.insert(connexions, ctx.evenementOutil.Event:Connect(function(joueur: unknown)
			if typeof(joueur) ~= "Instance" or not (joueur :: Instance):IsA("Player") then
				return
			end
			local fiche = fiches[joueur :: Player]
			if fiche then
				fiche.actionJusqua = math.max(fiche.actionJusqua, horloge() + R.DUREE_RAMASSAGE)
			end
		end))
	end

	-- Ce que le serveur voit du personnage (nil s'il n'y a rien à mesurer : pas de personnage, mort)
	local function mesurer(joueur: Player, fiche: Fiche, maintenant: number): (CalculNiveau.Mesure?, BasePart?)
		local perso = joueur.Character
		local racine = perso and perso:FindFirstChild("HumanoidRootPart")
		local humanoid = perso and perso:FindFirstChildOfClass("Humanoid")
		if not perso or not racine or not racine:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			return nil, nil
		end
		local v = racine.AssemblyLinearVelocity
		local auSol = humanoid.FloorMaterial ~= Enum.Material.Air
		if CalculNiveau.noterSol(fiche.etat, auSol, maintenant, R) then
			fiche.actionJusqua = math.max(fiche.actionJusqua, maintenant + R.DUREE_ATTERRISSAGE)
		end
		local outil = perso:FindFirstChildOfClass("Tool")
		return {
			vitesse = Vector3.new(v.X, 0, v.Z).Magnitude,
			auSol = auSol,
			nettoie = outil ~= nil and outil:GetAttribute(ctx.attributEnUtilisation) == true,
			actionJusqua = fiche.actionJusqua,
		}, racine
	end

	-- Bruits de corps (stades 1 à 3) : envoyés au monstre avec le stade brut.
	-- Un stade plus fort que le dernier envoyé part tout de suite (ex. il se met à courir).
	local function emettre(joueur: Player, fiche: Fiche, brut: number, racine: BasePart, maintenant: number)
		if brut <= 0 or brut >= R.STADE_NETTOYAGE then
			return
		end
		if brut > fiche.dernierStadeEmis or maintenant - fiche.derniereEmission >= R.PERIODE_EMISSION then
			fiche.derniereEmission = maintenant
			fiche.dernierStadeEmis = brut
			ctx.evenementBruit:Fire(racine.Position, nil, joueur, brut)
		end
	end

	task.spawn(function()
		while actif do
			local maintenant = horloge()
			for joueur, fiche in fiches do
				local mesure, racine = mesurer(joueur, fiche, maintenant)
				local brut = 0
				if mesure and racine then
					brut = CalculNiveau.stadeBrut(mesure, R, maintenant)
					emettre(joueur, fiche, brut, racine, maintenant)
				end
				if brut == 0 then
					fiche.dernierStadeEmis = 0
				end
				publier(joueur, fiche, CalculNiveau.lisser(fiche.etat, brut, maintenant, R))
			end
			task.wait(R.PERIODE_ANALYSE)
		end
	end)

	return {
		niveauDe = function(joueur: Player): number
			local fiche = fiches[joueur]
			return if fiche then fiche.etat.niveau else 0
		end,
		arreter = function()
			actif = false
			for _, c in connexions do
				c:Disconnect()
			end
			table.clear(connexions)
			table.clear(fiches)
		end,
	}
end

return ServiceBruit
