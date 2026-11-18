--[[
	Rôle    : fait bouger le squelette du monstre chez chaque joueur, avec les mêmes
	          calculs que le simulateur « Monstre du manoir » (marche et course), plus :
	          - respiration au repos (il n'est jamais figé comme une statue)
	          - bras qui se balancent à l'opposé des jambes en marchant
	          - posture d'alerte quand il repère un joueur (il se cabre, bras levés, tremble)
	          - posture de recherche (penché, il fouille du regard)
	          - penche dans les virages, genoux plus hauts dans l'escalier
	          Le serveur (MonstreIA) indique l'allure (attribut « Allure ») et l'état (« Etat »).
	          Le rythme des pas suit la vitesse réelle du monstre, lissée.
	          Tout est visuel (Motor6D.Transform côté client) : rien ne change la collision.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-18
]]

local RunService = game:GetService("RunService")

-- Mêmes réglages que le simulateur pour marche et course. arm = angle d'épaule vers l'avant.
-- Toutes les postures ont les mêmes clés : on passe de l'une à l'autre en douceur.
--   balance : balancement des bras pendant la marche
--   souffle : respiration (tronc et épaules)
--   tremble : tremblement nerveux (alerte)
--   scan    : le tronc fouille à gauche et à droite (recherche)
local MODES = {
	repos     = { freq = 0,   amp = 0,    knee = 0,   arm = 0,             lean = 0.05,  bob = 0,    balance = 0,    souffle = 1,   tremble = 0, scan = 0 },
	marche    = { freq = 3.4, amp = 0.36, knee = 0.6, arm = 0,             lean = 0.03,  bob = 0.07, balance = 0.22, souffle = 0.3, tremble = 0, scan = 0 },
	course    = { freq = 9.0, amp = 0.78, knee = 1.2, arm = math.rad(75),  lean = 0.2,   bob = 0.16, balance = 0.12, souffle = 0,   tremble = 0, scan = 0 },
	recherche = { freq = 0,   amp = 0,    knee = 0,   arm = math.rad(15),  lean = 0.15,  bob = 0,    balance = 0,    souffle = 0.6, tremble = 0, scan = 1 },
	alerte    = { freq = 0,   amp = 0,    knee = 0,   arm = math.rad(140), lean = -0.25, bob = 0,    balance = 0,    souffle = 0,   tremble = 1, scan = 0 },
}

-- Vitesse de transition vers chaque posture (plus grand = plus brusque).
-- L'alerte est brutale : c'est elle qui fait sursauter le joueur.
local VITESSE_TRANSITION = { alerte = 16 }
local VITESSE_TRANSITION_DEFAUT = 6

-- Vitesse (studs/s) pour laquelle la fréquence des pas du simulateur est juste
local VITESSE_REFERENCE = { marche = 10, course = 17 }
local SEUIL_ARRET = 1.0      -- en dessous : il est immobile
local SEUIL_DEPART = 2.5     -- au dessus : il se remet en mouvement (évite le clignotement)

local INCLINAISON_VIRAGE = 0.06 -- combien il penche dans les virages
local INCLINAISON_MAX = 0.25
local SENS_INCLINAISON = 1      -- mettre -1 s'il penche vers l'extérieur du virage au lieu de l'intérieur
local DISTANCE_MAX_ANIMATION = 300 -- plus loin que ça de la caméra, on n'anime pas (économie)

local monstre = workspace:WaitForChild("MonstreRodin")
local racine = monstre:WaitForChild("HumanoidRootPart")

local function moteur(nom)
	return monstre:WaitForChild(nom):WaitForChild(nom)
end
local corps = moteur("Corps")
local tronc = moteur("Tronc")
local hancheG, hancheD = moteur("HancheG"), moteur("HancheD")
local genouG, genouD = moteur("GenouG"), moteur("GenouD")
local epauleG, epauleD = moteur("EpauleG"), moteur("EpauleD")

-- three.js tourne dans l'autre sens que Roblox sur l'axe X
local function RX(a) return CFrame.Angles(-a, 0, 0) end

-- Lissage indépendant du nombre d'images par seconde
local function lissage(dt, vitesse)
	return 1 - math.exp(-vitesse * dt)
end

local DEUX_PI = 2 * math.pi
local p = table.clone(MODES.repos)
local phase = 0
local vitesseLissee = 0
local montee = 0         -- 0 = sol plat, 1 = escalier raide
local inclinaison = 0
local enMouvement = false
local lacetPrecedent = nil

RunService.RenderStepped:Connect(function(dt)
	if dt <= 0 then
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
	local allure = monstre:GetAttribute("Allure") or "repos"
	if etat == "alerte" then
		allure = "alerte"
	elseif not enMouvement then
		allure = (etat == "recherche") and "recherche" or "repos" -- immobile : il ne fait pas semblant de marcher
	end
	local cible = MODES[allure] or MODES.repos

	-- passage en douceur d'une posture à l'autre
	local k = lissage(dt, VITESSE_TRANSITION[allure] or VITESSE_TRANSITION_DEFAUT)
	for cle, valeur in pairs(cible) do
		p[cle] += (valeur - p[cle]) * k
	end

	-- les pas suivent la vitesse réelle : plus il va vite, plus les pas sont rapides
	local reference = VITESSE_REFERENCE[allure]
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

	-- virages : il penche vers l'intérieur, d'autant plus qu'il va vite
	local regard = racine.CFrame.LookVector
	local lacet = math.atan2(-regard.X, -regard.Z)
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

	-- effets lents : respiration, tremblement (sinus mélangés, jamais d'aléatoire qui grésille), fouille
	local souffle = math.sin(temps * 1.8) * 0.03 * p.souffle
	local tremble = (math.sin(temps * 37) + math.sin(temps * 53) * 0.6) * 0.03 * p.tremble
	local scan = math.sin(temps * 1.3) * 0.35 * p.scan

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
	epauleG.Transform = RX(-penche - p.arm - s * p.balance + tremble * 2)
	epauleD.Transform = RX(-penche - p.arm + s * p.balance - tremble * 2)
end)
