--!strict
--[[
	Rôle    : branche la règle d'endurance (Endurance) aux joueurs. Le SERVEUR décide de tout :
	          - le client envoie seulement « je veux courir / je n'y veux plus » (booléen) ;
	          - le serveur tient l'endurance, refuse la course à vide et pose lui-même WalkSpeed ;
	          - il publie sur le Player trois attributs (Endurance, Epuise, Court) que le client
	            affiche sans rien décider.
	          Cycle de vie : un état neuf (jauge pleine, plus de demande) à chaque personnage ;
	          rien ne reste après PlayerRemoving. Dépendances reçues par ctx (inversion de dépendance).
	          WalkSpeed n'est touché nulle part ailleurs pour les joueurs (vérifié : seul MonstreIA
	          règle la vitesse de SON Humanoid). Vies.server ne la change pas non plus.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Endurance = require(script.Parent:WaitForChild("Endurance"))

type Etat = Endurance.Etat

type Fiche = {
	etat: Etat,
	veutCourir: boolean,
	humanoid: Humanoid?,
	racine: BasePart?,
	dernierePublication: number,
	publieEndurance: number,
	publieEpuise: boolean,
	publieCourt: boolean,
}

export type Contexte = {
	reglages: any,                                  -- ReglagesSprint
	remote: RemoteEvent,                            -- DemanderCourse
	limiteur: { consommer: (Player, number?) -> boolean, oublier: (Player) -> () },
}

export type ServiceSprint = {
	etatDe: (joueur: Player) -> Etat?,              -- lecture seule (tests, futur HUD serveur)
	arreter: () -> (),
}

local ServiceSprint = {}

function ServiceSprint.demarrer(ctx: Contexte): ServiceSprint
	local R = ctx.reglages
	local fiches: { [Player]: Fiche } = {}
	local connexions: { RBXScriptConnection } = {}

	local function publier(joueur: Player, fiche: Fiche, maintenant: number, force: boolean)
		local etat = fiche.etat
		local arrondi = math.floor(etat.endurance * 100 + 0.5) / 100
		local boolChange = fiche.publieEpuise ~= etat.epuise or fiche.publieCourt ~= etat.court
		local bord = arrondi ~= fiche.publieEndurance and (arrondi <= 0 or arrondi >= 1)
		if not (force or boolChange or bord or (arrondi ~= fiche.publieEndurance
			and maintenant - fiche.dernierePublication >= R.PERIODE_PUBLICATION)) then
			return
		end
		fiche.dernierePublication = maintenant
		fiche.publieEndurance, fiche.publieEpuise, fiche.publieCourt = arrondi, etat.epuise, etat.court
		joueur:SetAttribute(R.ATTRIBUT_ENDURANCE, arrondi)
		joueur:SetAttribute(R.ATTRIBUT_EPUISE, etat.epuise)
		joueur:SetAttribute(R.ATTRIBUT_COURT, etat.court)
	end

	local function reinitialiser(joueur: Player, fiche: Fiche)
		fiche.etat = Endurance.nouvelEtat()
		fiche.veutCourir = false
		publier(joueur, fiche, os.clock(), true)
	end

	-- Un personnage neuf : tout repart de zéro (jauge pleine, pas de demande en cours)
	local function lierPersonnage(joueur: Player, personnage: Model)
		local fiche = fiches[joueur]
		if not fiche or joueur.Character ~= personnage then
			return
		end
		reinitialiser(joueur, fiche)
		fiche.humanoid, fiche.racine = nil, nil
		local humanoid = personnage:WaitForChild("Humanoid", 10)
		local racine = personnage:WaitForChild("HumanoidRootPart", 10)
		-- un respawn pendant l'attente : ce personnage n'est plus le bon
		if not humanoid or not racine or fiches[joueur] ~= fiche or joueur.Character ~= personnage then
			return
		end
		if not humanoid:IsA("Humanoid") or not racine:IsA("BasePart") then
			return
		end
		fiche.humanoid, fiche.racine = humanoid, racine
		humanoid.WalkSpeed = R.VITESSE_MARCHE
	end

	local function ajouter(joueur: Player)
		if fiches[joueur] then
			return
		end
		local fiche: Fiche = {
			etat = Endurance.nouvelEtat(),
			veutCourir = false,
			humanoid = nil,
			racine = nil,
			dernierePublication = 0,
			publieEndurance = -1,
			publieEpuise = false,
			publieCourt = false,
		}
		fiches[joueur] = fiche
		publier(joueur, fiche, os.clock(), true)
		table.insert(connexions, joueur.CharacterAdded:Connect(function(personnage)
			lierPersonnage(joueur, personnage)
		end))
		table.insert(connexions, joueur.CharacterRemoving:Connect(function()
			local f = fiches[joueur]
			if f then
				f.humanoid, f.racine, f.veutCourir = nil, nil, false
			end
		end))
		if joueur.Character then
			task.spawn(lierPersonnage, joueur, joueur.Character)
		end
	end

	table.insert(connexions, Players.PlayerAdded:Connect(ajouter))
	for _, joueur in Players:GetPlayers() do
		ajouter(joueur)
	end

	table.insert(connexions, Players.PlayerRemoving:Connect(function(joueur)
		fiches[joueur] = nil
		ctx.limiteur.oublier(joueur)
	end))

	-- Demande du client : on valide le type et le débit, rien d'autre n'est cru
	table.insert(connexions, ctx.remote.OnServerEvent:Connect(function(joueur: Player, veutCourir: unknown)
		if typeof(veutCourir) ~= "boolean" then
			return
		end
		if not ctx.limiteur.consommer(joueur, 1) then
			return
		end
		local fiche = fiches[joueur]
		if fiche then
			fiche.veutCourir = veutCourir
		end
	end))

	-- Boucle : à chaque image, l'état de chaque joueur avance et la vitesse est posée
	local dernier = os.clock()
	table.insert(connexions, RunService.Heartbeat:Connect(function()
		local maintenant = os.clock()
		local dt = maintenant - dernier
		dernier = maintenant
		for joueur, fiche in fiches do
			local humanoid, racine = fiche.humanoid, fiche.racine
			if humanoid and racine and humanoid.Parent and humanoid.Health > 0 then
				local v = racine.AssemblyLinearVelocity
				local enMouvement = Vector3.new(v.X, 0, v.Z).Magnitude > R.VITESSE_MIN_MOUVEMENT
				Endurance.avancer(fiche.etat, R, dt, maintenant, fiche.veutCourir, enMouvement)
				local voulue = if fiche.etat.court then R.VITESSE_COURSE else R.VITESSE_MARCHE
				if humanoid.WalkSpeed ~= voulue then
					humanoid.WalkSpeed = voulue
				end
			else
				-- mort ou pas encore de personnage : plus de course, la jauge se remplit
				fiche.veutCourir = false
				Endurance.avancer(fiche.etat, R, dt, maintenant, false, false)
			end
			publier(joueur, fiche, maintenant, false)
		end
	end))

	return {
		etatDe = function(joueur: Player): Etat?
			local fiche = fiches[joueur]
			return fiche and fiche.etat
		end,
		arreter = function()
			for _, c in connexions do
				c:Disconnect()
			end
			table.clear(connexions)
			table.clear(fiches)
		end,
	}
end

return ServiceSprint
