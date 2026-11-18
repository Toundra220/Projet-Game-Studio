--[[
	Rôle    : fait bouger le squelette du monstre chez chaque joueur, avec les mêmes
	          calculs que le simulateur « Monstre du manoir » (marche et course).
	          Le serveur (MonstreIA) indique l'allure dans l'attribut « Allure ».
	          Le rythme des pas suit la vitesse réelle du monstre, et la vitesse est
	          lissée pour que l'animation ne se fige jamais entre deux points du chemin.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-17
]]

local RunService = game:GetService("RunService")

-- Mêmes réglages que le simulateur. arm = angle d'épaule vers l'avant.
local MODES = {
	repos  = { freq = 0,   amp = 0,    knee = 0,   arm = 0,            lean = 0,    bob = 0 },
	marche = { freq = 3.4, amp = 0.36, knee = 0.6, arm = 0,            lean = 0.03, bob = 0.07 },
	course = { freq = 9.0, amp = 0.78, knee = 1.2, arm = math.rad(75), lean = 0.2,  bob = 0.16 },
}

-- Vitesse (studs/s) pour laquelle la fréquence des pas du simulateur est juste
local VITESSE_REFERENCE = { marche = 10, course = 17 }
local SEUIL_ARRET = 1.0      -- en dessous : il est immobile
local SEUIL_DEPART = 2.5     -- au dessus : il se remet en mouvement (évite le clignotement)

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

local p = table.clone(MODES.repos)
local phase = 0
local vitesseLissee = 0
local enMouvement = false

RunService.RenderStepped:Connect(function(dt)
	-- vitesse à plat (on ignore la chute), lissée pour éviter les à-coups
	local v = racine.AssemblyLinearVelocity
	local vitesse = Vector3.new(v.X, 0, v.Z).Magnitude
	vitesseLissee += (vitesse - vitesseLissee) * math.min(1, dt * 8)

	-- marche/arrêt avec deux seuils : plus de basculement à chaque petit ralentissement
	if enMouvement and vitesseLissee < SEUIL_ARRET then
		enMouvement = false
	elseif not enMouvement and vitesseLissee > SEUIL_DEPART then
		enMouvement = true
	end

	local allure = monstre:GetAttribute("Allure") or "repos"
	if not enMouvement then
		allure = "repos" -- immobile : il ne fait pas semblant de marcher
	end
	local cible = MODES[allure] or MODES.repos
	-- passage en douceur d'une allure à l'autre
	local k = math.min(1, dt * 6)
	for cle, valeur in pairs(cible) do
		p[cle] += (valeur - p[cle]) * k
	end

	-- les pas suivent la vitesse réelle : plus il va vite, plus les pas sont rapides
	local reference = VITESSE_REFERENCE[allure]
	local rythme = 1
	if reference then
		rythme = math.clamp(vitesseLissee / reference, 0.6, 1.5)
	end
	phase += p.freq * rythme * dt

	local s = math.sin(phase)
	local c = math.cos(phase)
	hancheG.Transform = RX(-s * p.amp)
	hancheD.Transform = RX(s * p.amp)
	genouG.Transform = RX(math.max(0, c) * p.knee + p.knee * 0.12)
	genouD.Transform = RX(math.max(0, -c) * p.knee + p.knee * 0.12)
	corps.Transform = CFrame.new(0, -(1 - math.cos(p.amp)) * 3.6 + math.abs(c) * p.bob, 0)
	tronc.Transform = RX(p.lean)
	-- les épaules compensent la penche du tronc : à 0 les bras pendent à la verticale
	epauleG.Transform = RX(-p.lean - p.arm)
	epauleD.Transform = RX(-p.lean - p.arm)
end)
