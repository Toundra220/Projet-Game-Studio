--[[
	Rôle    : fait bouger le squelette du monstre chez chaque joueur, avec les mêmes
	          calculs que le simulateur « Monstre du manoir » (marche et course).
	          Le serveur (MonstreIA) indique l'allure dans l'attribut « Allure ».
	Origine : ÉCRIT (ébauche à relire et adapter)
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

RunService.RenderStepped:Connect(function(dt)
	local allure = monstre:GetAttribute("Allure") or "repos"
	if racine.AssemblyLinearVelocity.Magnitude < 0.5 then
		allure = "repos" -- immobile : il ne fait pas semblant de marcher
	end
	local cible = MODES[allure] or MODES.repos
	-- passage en douceur d'une allure à l'autre
	local k = math.min(1, dt * 6)
	for cle, valeur in pairs(cible) do
		p[cle] += (valeur - p[cle]) * k
	end
	phase += p.freq * dt

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
