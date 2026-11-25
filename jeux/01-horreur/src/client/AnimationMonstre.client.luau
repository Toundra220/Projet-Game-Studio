--[[
	Rôle    : fait bouger le squelette du monstre chez chaque joueur (animation procédurale,
	          aucune animation Roblox importée), avec les mêmes calculs que le simulateur
	          « Monstre du manoir » pour la marche et la course, plus :
	          - respiration au repos (il n'est jamais figé comme une statue)
	          - bras qui se balancent à l'opposé des jambes, coudes pliés selon l'allure
	          - enquête : pas pressés, tête tendue en avant
	          - recherche en marchant : démarche lente et voûtée, mains tendues devant lui
	          - soupçon : figé, tête penchée sur le côté avec des tics nerveux (insecte)
	          - alerte : il se cabre, bras levés, tremble
	          - attaque : il se jette en avant, bras tendus
	          - la tête suit ce qu'il regarde (attribut « Regard » du serveur)
	          - penche dans les virages, genoux plus hauts dans l'escalier
	          Sons facultatifs : si le modèle contient des Sound nommés SonPas, SonDetection ou
	          SonApproche (à ajouter avec nos propres sons), ils sont joués ici, en local.
	          Yeux : attribut Yeux du modèle (texte) : "noirs" (orbites vides, comme le sprite),
	          "rouges" (toujours rouges) ou "rouges_en_chasse" (rouges en alerte, poursuite, attaque).
	          Le serveur (MonstreIA) indique l'allure (« Allure ») et l'état (« Etat »).
	          Tout est visuel (Motor6D.Transform côté client) : rien ne change la collision.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-18 (postures, tête, coudes et sons : 2026-11-24 ; nouveau modèle et yeux : 2026-11-25 ; attribut Present : 2026-11-25)
]]

local RunService = game:GetService("RunService")

-- Postures. Toutes ont les mêmes clés : on passe de l'une à l'autre en douceur.
--   freq/amp/knee/bob : pas (fréquence, amplitude des hanches, genoux, rebond)
--   arm     : angle d'épaule vers l'avant ; balance : balancement des bras en marchant
--   coude   : pli des coudes vers l'avant
--   lean    : penche du tronc vers l'avant
--   teteBas : tête baissée (par rapport à l'horizon) ; inclineTete : tête penchée sur le côté
--   souffle : respiration ; tremble : tremblement nerveux ; tic : petits à-coups de la tête
--   scan    : le tronc fouille à gauche et à droite
local MODES = {
	repos     = { freq = 0,   amp = 0,    knee = 0,   arm = 0,             balance = 0,    coude = 0.15, lean = 0.05,  teteBas = 0.1,   inclineTete = 0,    bob = 0,    souffle = 1,   tremble = 0,   tic = 0,   scan = 0 },
	marche    = { freq = 3.4, amp = 0.36, knee = 0.6, arm = 0,             balance = 0.22, coude = 0.3,  lean = 0.03,  teteBas = 0.05,  inclineTete = 0,    bob = 0.07, souffle = 0.3, tremble = 0,   tic = 0,   scan = 0 },
	enquete   = { freq = 3.8, amp = 0.4,  knee = 0.7, arm = math.rad(10),  balance = 0.15, coude = 0.45, lean = 0.12,  teteBas = -0.05, inclineTete = 0,    bob = 0.08, souffle = 0.2, tremble = 0,   tic = 0.3, scan = 0 },
	prudent   = { freq = 2.4, amp = 0.28, knee = 0.7, arm = math.rad(35),  balance = 0.08, coude = 0.9,  lean = 0.3,   teteBas = 0.15,  inclineTete = 0.1,  bob = 0.05, souffle = 0.4, tremble = 0,   tic = 0.4, scan = 0.5 },
	course    = { freq = 9.0, amp = 0.78, knee = 1.2, arm = math.rad(75),  balance = 0.12, coude = 0.5,  lean = 0.2,   teteBas = -0.1,  inclineTete = 0,    bob = 0.16, souffle = 0,   tremble = 0,   tic = 0,   scan = 0 },
	recherche = { freq = 0,   amp = 0,    knee = 0,   arm = math.rad(15),  balance = 0,    coude = 0.5,  lean = 0.15,  teteBas = 0.15,  inclineTete = 0.15, bob = 0,    souffle = 0.6, tremble = 0,   tic = 0.5, scan = 1 },
	soupcon   = { freq = 0,   amp = 0,    knee = 0,   arm = math.rad(25),  balance = 0,    coude = 0.7,  lean = 0.22,  teteBas = 0,     inclineTete = 0.4,  bob = 0,    souffle = 0.2, tremble = 0.2, tic = 1,   scan = 0 },
	-- alerte : bras levés à 115° (et non 140°) : avec ses bras très longs, les griffes passaient
	-- au-dessus des linteaux de porte (17,7 studs au RdC)
	alerte    = { freq = 0,   amp = 0,    knee = 0,   arm = math.rad(115), balance = 0,    coude = 0.2,  lean = -0.25, teteBas = -0.2,  inclineTete = 0,    bob = 0,    souffle = 0,   tremble = 1,   tic = 0.6, scan = 0 },
	attaque   = { freq = 0,   amp = 0,    knee = 0.3, arm = math.rad(110), balance = 0,    coude = 0.05, lean = 0.5,   teteBas = 0.25,  inclineTete = 0,    bob = 0,    souffle = 0,   tremble = 0.4, tic = 0,   scan = 0 },
}

-- Vitesse de transition vers chaque posture (plus grand = plus brusque).
-- Alerte et attaque sont brutales : ce sont elles qui font sursauter le joueur.
local VITESSE_TRANSITION = { alerte = 16, attaque = 20, soupcon = 10 }
local VITESSE_TRANSITION_DEFAUT = 6

-- Vitesse (studs/s) pour laquelle la fréquence des pas est juste
local VITESSE_REFERENCE = { marche = 10, enquete = 14, prudent = 8, course = 17 }
local SEUIL_ARRET = 1.0      -- en dessous : il est immobile
local SEUIL_DEPART = 2.5     -- au dessus : il se remet en mouvement (évite le clignotement)

local BRAS_ESCALIER = 0.5     -- dans l'escalier : bras levés vers l'avant (radians)...
local COUDE_ESCALIER = 1.1     -- ...et coudes pliés, pour que les griffes ne traversent pas les marches
local DISTANCE_ANTICIPATION_MARCHE = 4 -- studs devant lui où l'on regarde si le sol monte
local INCLINAISON_VIRAGE = 0.06 -- combien il penche dans les virages
local INCLINAISON_MAX = 0.25
local SENS_INCLINAISON = 1      -- mettre -1 s'il penche vers l'extérieur du virage au lieu de l'intérieur
local DISTANCE_MAX_ANIMATION = 300 -- plus loin que ça de la caméra, on n'anime pas (économie)

-- Tête qui suit le regard
local LACET_TETE_MAX = math.rad(70)
local TANGAGE_TETE_MAX = math.rad(35)
local SENS_LACET_TETE = 1       -- mettre -1 si la tête tourne du mauvais côté
local SENS_TANGAGE_TETE = 1     -- mettre -1 si la tête lève quand elle devrait baisser

-- Sons facultatifs (volume de base = celui réglé sur le Sound)
local VOLUME_APPROCHE_CALME = 0.45 -- fraction du volume de SonApproche hors poursuite
local VARIATION_PAS = 0.08         -- hauteur des pas : +/- 8 % (évite l'effet mitraillette)

local monstre = workspace:WaitForChild("MonstreRodin")
local racine = monstre:WaitForChild("HumanoidRootPart")
local humanoidMonstre = monstre:FindFirstChildOfClass("Humanoid")
-- distance racine -> sol quand il est debout (HipHeight + demi-hauteur de la racine)
local hauteurRacine = (humanoidMonstre and humanoidMonstre.HipHeight or 6) + racine.Size.Y / 2
-- rayons vers le sol (anticipation des marches) : on ignore le monstre et ce qu'on traverse
local paramsSol = RaycastParams.new()
paramsSol.FilterType = Enum.RaycastFilterType.Exclude
paramsSol.FilterDescendantsInstances = { monstre }
paramsSol.RespectCanCollide = true

local function moteur(nom)
	return monstre:WaitForChild(nom):WaitForChild(nom)
end
-- Moteurs facultatifs : s'ils manquent, le reste de l'animation fonctionne quand même
local function moteurFacultatif(nom)
	local partie = monstre:WaitForChild(nom, 5)
	local m = partie and partie:WaitForChild(nom, 5)
	if m and m:IsA("Motor6D") then
		return m
	end
	return nil
end
local corps = moteur("Corps")
local tronc = moteur("Tronc")
local hancheG, hancheD = moteur("HancheG"), moteur("HancheD")
local genouG, genouD = moteur("GenouG"), moteur("GenouD")
local epauleG, epauleD = moteur("EpauleG"), moteur("EpauleD")
local coudeG, coudeD = moteurFacultatif("CoudeG"), moteurFacultatif("CoudeD")
local cou, teteMoteur = moteurFacultatif("Cou"), moteurFacultatif("Tete")
local partieTete = monstre:FindFirstChild("Tete")

-- three.js tourne dans l'autre sens que Roblox sur l'axe X
local function RX(a) return CFrame.Angles(-a, 0, 0) end

-- Lissage indépendant du nombre d'images par seconde
local function lissage(dt, vitesse)
	return 1 - math.exp(-vitesse * dt)
end

-- Sons : cherchés dans tout le modèle, et à nouveau si on en ajoute un
local sons = {}
local volumesBase = {}
local function chercherSons()
	for _, nom in { "SonPas", "SonDetection", "SonApproche" } do
		local s = monstre:FindFirstChild(nom, true)
		sons[nom] = (s and s:IsA("Sound")) and s or nil
		if sons[nom] and not volumesBase[sons[nom]] then
			volumesBase[sons[nom]] = sons[nom].Volume
		end
	end
end
chercherSons()
monstre.DescendantAdded:Connect(function(d)
	if d:IsA("Sound") then
		chercherSons()
	end
end)

local aleatoire = Random.new()
local function jouerPas(force)
	local s = sons.SonPas
	if not s then
		return
	end
	s.PlaybackSpeed = 1 + aleatoire:NextNumber(-VARIATION_PAS, VARIATION_PAS)
	s.Volume = (volumesBase[s] or s.Volume) * force
	s:Play()
end

-- Son de détection : une fois à chaque passage en alerte
monstre:GetAttributeChangedSignal("Etat"):Connect(function()
	if monstre:GetAttribute("Etat") == "alerte" and sons.SonDetection then
		sons.SonDetection:Play()
	end
end)

-- Yeux : orbites noires (sprite) ou rouges (fiche Monstre du coffre), au choix de Romain
-- via l'attribut Yeux du modèle. Purement visuel et local.
local ROUGE_YEUX = Color3.fromRGB(200, 20, 20)
local ETATS_CHASSE = { alerte = true, poursuite = true, attaque = true }
local orbites = {}
for _, nom in { "OrbiteG", "OrbiteD" } do
	local o = monstre:WaitForChild(nom, 5)
	if o and o:IsA("BasePart") then
		table.insert(orbites, { partie = o, couleur = o.Color, matiere = o.Material })
	end
end
local function mettreAJourYeux()
	local choix = monstre:GetAttribute("Yeux")
	local rouges = choix == "rouges"
		or (choix == "rouges_en_chasse" and ETATS_CHASSE[monstre:GetAttribute("Etat")] == true)
	for _, o in orbites do
		o.partie.Color = rouges and ROUGE_YEUX or o.couleur
		o.partie.Material = rouges and Enum.Material.Neon or o.matiere
	end
end
mettreAJourYeux()
monstre:GetAttributeChangedSignal("Yeux"):Connect(mettreAJourYeux)
monstre:GetAttributeChangedSignal("Etat"):Connect(mettreAJourYeux)

local DEUX_PI = 2 * math.pi
local p = table.clone(MODES.repos)
local phase = 0
local vitesseLissee = 0
local montee = 0         -- 0 = sol plat, 1 = escalier raide
local brasEscalier = 0   -- 0 = bras pendants, 1 = bras repliés (escalier)
local inclinaison = 0
local enMouvement = false
local lacetPrecedent = nil
local signePas = 1
local lacetTete, tangageTete = 0, 0
local volumeApproche = 0

RunService.RenderStepped:Connect(function(dt)
	if dt <= 0 then
		return
	end
	-- rangé sous sa chambre tant que personne n'a ramassé le balai : rien à animer
	if monstre:GetAttribute("Present") == false then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - racine.Position).Magnitude > DISTANCE_MAX_ANIMATION then
		return
	end
	local temps = os.clock()

	-- vitesse à plat (on ignore la chute), lissée pour éviter les à-coups
	local v = racine.AssemblyLinearVelocity
	local vitesse = Vector3.new(v.X, 0, v.Z).Magnitude
	vitesseLissee += (vitesse - vitesseLissee) * lissage(dt, 8)

	-- marche/arrêt avec deux seuils : plus de basculement à chaque petit ralentissement
	if enMouvement and vitesseLissee < SEUIL_ARRET then
		enMouvement = false
	elseif not enMouvement and vitesseLissee > SEUIL_DEPART then
		enMouvement = true
	end

	-- choix de la posture : l'état du serveur passe avant l'allure
	local etat = monstre:GetAttribute("Etat")
	local mode = monstre:GetAttribute("Allure") or "repos"
	if etat == "alerte" or etat == "attaque" or etat == "soupcon" then
		mode = etat
	elseif not enMouvement then
		mode = (etat == "recherche") and "recherche" or "repos" -- immobile : il ne fait pas semblant de marcher
	elseif etat == "recherche" then
		mode = "prudent"
	elseif etat == "enquete" then
		mode = "enquete"
	end
	local cible = MODES[mode] or MODES.repos

	-- passage en douceur d'une posture à l'autre
	local k = lissage(dt, VITESSE_TRANSITION[mode] or VITESSE_TRANSITION_DEFAUT)
	for cle, valeur in pairs(cible) do
		p[cle] += (valeur - p[cle]) * k
	end

	-- les pas suivent la vitesse réelle : plus il va vite, plus les pas sont rapides
	local reference = VITESSE_REFERENCE[mode]
	local rythme = 1
	if reference then
		rythme = math.clamp(vitesseLissee / reference, 0.6, 1.5)
	end
	phase = (phase + p.freq * rythme * dt) % DEUX_PI

	-- escalier : il lève plus les genoux quand il monte ou descend
	local penteVoulue = enMouvement and math.clamp(math.abs(v.Y) / 8, 0, 1) or 0
	montee += (penteVoulue - montee) * lissage(dt, 5)
	local amp = p.amp * (1 + 0.2 * montee)
	local knee = p.knee * (1 + 0.6 * montee)
	-- ses griffes pendent plus bas que ses genoux : dans l'escalier il replie les bras
	-- vers l'avant, sinon elles traversent les marches (constaté en Play le 2026-11-25).
	-- Un rayon vers le sol, devant lui, anticipe la première marche.
	local brasVoulu = math.clamp(montee * 2, 0, 1)
	if enMouvement then
		local regard = racine.CFrame.LookVector
		local devant = racine.Position + Vector3.new(regard.X, 0, regard.Z) * DISTANCE_ANTICIPATION_MARCHE
		local sol = workspace:Raycast(devant, Vector3.new(0, -(hauteurRacine + 4), 0), paramsSol)
		if sol then
			local solSousLui = racine.Position.Y - hauteurRacine
			brasVoulu = math.max(brasVoulu, math.clamp((sol.Position.Y - solSousLui - 0.3) / 1.2, 0, 1))
		end
	end
	brasEscalier += (brasVoulu - brasEscalier) * lissage(dt, 10)

	-- virages : il penche vers l'intérieur, d'autant plus qu'il va vite
	local regardCorps = racine.CFrame.LookVector
	local lacet = math.atan2(-regardCorps.X, -regardCorps.Z)
	local vitesseRotation = 0
	if lacetPrecedent then
		local dLacet = (lacet - lacetPrecedent + math.pi) % DEUX_PI - math.pi
		vitesseRotation = dLacet / dt
	end
	lacetPrecedent = lacet
	local inclinaisonVoulue = 0
	if enMouvement then
		local facteurVitesse = math.clamp(vitesseLissee / VITESSE_REFERENCE.course, 0, 1.5)
		inclinaisonVoulue = math.clamp(-vitesseRotation * INCLINAISON_VIRAGE * facteurVitesse, -INCLINAISON_MAX, INCLINAISON_MAX)
	end
	inclinaison += (inclinaisonVoulue - inclinaison) * lissage(dt, 6)

	-- effets lents : respiration, tremblement, tics (sinus mélangés, jamais d'aléatoire qui grésille), fouille
	local souffle = math.sin(temps * 1.8) * 0.03 * p.souffle
	local tremble = (math.sin(temps * 37) + math.sin(temps * 53) * 0.6) * 0.03 * p.tremble
	local scan = math.sin(temps * 1.3) * 0.35 * p.scan
	-- tic : produit de deux sinus à la puissance 8 = de rares à-coups brefs
	local tic = (math.max(0, math.sin(temps * 1.7) * math.sin(temps * 3.1)) ^ 8) * 0.6 * p.tic

	local s = math.sin(phase)
	local c = math.cos(phase)
	hancheG.Transform = RX(-s * amp)
	hancheD.Transform = RX(s * amp)
	genouG.Transform = RX(math.max(0, c) * knee + knee * 0.12)
	genouD.Transform = RX(math.max(0, -c) * knee + knee * 0.12)
	corps.Transform = CFrame.new(0, -(1 - math.cos(amp)) * 3.6 + math.abs(c) * p.bob, 0)
	tronc.Transform = RX(p.lean + souffle + tremble)
		* CFrame.Angles(0, scan, inclinaison * SENS_INCLINAISON)
	-- les épaules compensent la penche du tronc : à 0 les bras pendent à la verticale.
	-- Chaque bras se balance à l'opposé de la jambe du même côté.
	local penche = p.lean + souffle + tremble
	local brasLeve = BRAS_ESCALIER * brasEscalier
	epauleG.Transform = RX(-penche - p.arm - brasLeve - s * p.balance + tremble * 2)
	epauleD.Transform = RX(-penche - p.arm - brasLeve + s * p.balance - tremble * 2)
	if coudeG and coudeD then
		-- le coude se plie un peu plus quand le bras part vers l'avant
		local coudeEscalier = COUDE_ESCALIER * brasEscalier
		coudeG.Transform = RX(-p.coude - coudeEscalier - math.max(0, s) * p.balance * 0.8)
		coudeD.Transform = RX(-p.coude - coudeEscalier - math.max(0, -s) * p.balance * 0.8)
	end

	-- tête : suit le point que le serveur lui fait regarder, sinon regarde devant
	local lacetVoulu, tangageVoulu = 0, 0
	local pointRegarde = monstre:GetAttribute("Regard")
	if typeof(pointRegarde) == "Vector3" then
		local relatif = racine.CFrame:PointToObjectSpace(pointRegarde)
		local hauteurYeux = partieTete and (partieTete.Position.Y - racine.Position.Y) or 3
		local horizontal = Vector3.new(relatif.X, 0, relatif.Z).Magnitude
		if horizontal > 0.5 then
			lacetVoulu = math.clamp(math.atan2(-relatif.X, -relatif.Z), -LACET_TETE_MAX, LACET_TETE_MAX)
			tangageVoulu = math.clamp(-math.atan2(relatif.Y - hauteurYeux, horizontal), -TANGAGE_TETE_MAX, TANGAGE_TETE_MAX)
		end
	end
	lacetTete += (lacetVoulu - lacetTete) * lissage(dt, 8)
	tangageTete += (tangageVoulu - tangageTete) * lissage(dt, 8)
	-- la tête annule la fouille du tronc et une partie de sa penche (elle reste vers sa cible)
	local lacetFinal = (lacetTete - scan) * SENS_LACET_TETE
	local tangageFinal = tangageTete * SENS_TANGAGE_TETE + p.teteBas - penche * 0.7
	if cou then
		cou.Transform = CFrame.Angles(0, lacetFinal * 0.5, 0) * RX(tangageFinal * 0.4)
	end
	if teteMoteur then
		teteMoteur.Transform = RX(tangageFinal * 0.6 + tic * 0.5)
			* CFrame.Angles(0, lacetFinal * 0.5, p.inclineTete + tic)
	end

	-- sons de pas : un à chaque appui (quand le sinus de la phase change de signe)
	local signe = s >= 0 and 1 or -1
	if signe ~= signePas then
		signePas = signe
		if enMouvement and p.freq > 1 then
			jouerPas(math.clamp(vitesseLissee / VITESSE_REFERENCE.course, 0.3, 1))
		end
	end

	-- son d'approche (boucle) : discret en patrouille, plus fort quand il chasse
	local approche = sons.SonApproche
	if approche then
		local voulu = 0
		if etat and etat ~= "attente" then
			voulu = (etat == "poursuite" or etat == "alerte" or etat == "attaque") and 1 or VOLUME_APPROCHE_CALME
		end
		volumeApproche += (voulu - volumeApproche) * lissage(dt, 2)
		if volumeApproche > 0.01 then
			approche.Looped = true
			approche.Volume = (volumesBase[approche] or 0.5) * volumeApproche
			if not approche.IsPlaying then
				approche:Play()
			end
		elseif approche.IsPlaying then
			approche:Stop()
		end
	end
end)
