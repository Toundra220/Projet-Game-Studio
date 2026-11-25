--[[
	Rôle    : outil d'atelier (jamais requis par le jeu, hors arbre Rojo) : reconstruit
	          Workspace.MonstreRodin d'après docs/conception/sprite3D du monstre.jpg
	          (Parts, ellipsoïdes SpecialMesh Sphere, 12 Motor6D aux noms lus par AnimationMonstre.client).
	          Garde le Model, ses attributs, le Humanoid et le HumanoidRootPart ; remplace tout le reste.
	          Copie dans la place : ServerStorage.SauvegardesMonstre["ConstruireMonstre_2026-11-25"].
	          Usage (barre de commande, mode Edit) :
	            require(game.ServerStorage.SauvegardesMonstre["ConstruireMonstre_2026-11-25"]:Clone())
	          Réglages en tête : S (échelle, 0.96 = 15,6 studs ; portes 17,7), SOL (point au sol sous
	          les hanches), VISE (direction du regard). Après reconstruction : vérifier
	          ModelStreamingMode = Persistent sur le modèle (propriété gardée, pas recréée ici).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-25
]]
local S = 0.96
local SOL = Vector3.new(40, 33, 26) -- Chambre 1, au pied du lit
local VISE = Vector3.new(70.9, 33, 80) -- il regarde vers la porte de la chambre

local m = workspace.MonstreRodin
local hum = m:FindFirstChildOfClass("Humanoid")
local hrp = m:FindFirstChild("HumanoidRootPart")
for _, c in m:GetChildren() do
	if c ~= hum and c ~= hrp then c:Destroy() end
end

local B = CFrame.lookAt(SOL, VISE)
local function W(v) return B * (v * S) end
local function CFl(v, rot) return B * CFrame.new(v * S) * (rot or CFrame.identity) end
local rad = math.rad
local function RX(a) return CFrame.Angles(rad(a), 0, 0) end

-- Couleurs et matières (sobres, pas de néon)
local PEAU = Color3.fromRGB(62, 47, 42)
local PEAU_SOMBRE = Color3.fromRGB(42, 32, 29)
local COTE = Color3.fromRGB(88, 68, 60)
local MASQUE = Color3.fromRGB(196, 188, 178)
local CONE = Color3.fromRGB(27, 26, 27)
local NOIR = Color3.fromRGB(8, 7, 7)
local MAT_PEAU = Enum.Material.Leather
local MAT_MASQUE = Enum.Material.SmoothPlastic
local MAT_CONE = Enum.Material.Slate

local tampon = Instance.new("Folder") -- construit hors du DataModel, puis transféré
local nbParties = 0
local function base(nom, couleur, mat)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = couleur or PEAU
	p.Material = mat or MAT_PEAU
	nbParties += 1
	return p
end
local function souder(p, os)
	local w = Instance.new("Weld")
	w.Part0 = os
	w.Part1 = p
	w.C0 = os.CFrame:ToObjectSpace(p.CFrame)
	w.Parent = p
	p.Parent = tampon
	return p
end
local function ellipsoide(nom, os, centre, taille, rot, couleur, mat)
	local p = base(nom, couleur, mat)
	p.Size = taille * S
	p.CFrame = CFl(centre, rot)
	local me = Instance.new("SpecialMesh")
	me.MeshType = Enum.MeshType.Sphere
	me.Parent = p
	return souder(p, os)
end
local function boule(nom, os, centre, d, couleur, mat)
	local p = base(nom, couleur, mat)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * d * S
	p.CFrame = CFl(centre)
	return souder(p, os)
end
local function cylindreW(nom, os, A, Bp, r, couleur, mat) -- points monde
	local d = Bp - A
	local dir = d.Unit
	local ref = math.abs(dir:Dot(B.UpVector)) > 0.95 and B.LookVector or B.UpVector
	local vY = ref:Cross(dir).Unit
	local p = base(nom, couleur, mat)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(d.Magnitude, 2 * r * S, 2 * r * S)
	p.CFrame = CFrame.fromMatrix((A + Bp) / 2, dir, vY)
	return souder(p, os)
end
local function cylindre(nom, os, a, b, r, couleur, mat) -- points locaux
	return cylindreW(nom, os, W(a), W(b), r, couleur, mat)
end

-- Os (Motor6D) : mêmes noms que l'ancien modèle (AnimationMonstre.client)
local function os_(nom, pos)
	local p = base(nom, PEAU_SOMBRE, Enum.Material.SmoothPlastic)
	p.Size = Vector3.one * 0.2
	p.Transparency = 1
	p.CFrame = CFl(pos)
	p.Parent = tampon
	return p
end
local function moteur(parent, enfant, pivotLocal)
	local mo = Instance.new("Motor6D")
	mo.Name = enfant.Name
	mo.Part0 = parent
	mo.Part1 = enfant
	local pivot = pivotLocal and CFl(pivotLocal) or enfant.CFrame
	mo.C0 = parent.CFrame:ToObjectSpace(pivot)
	mo.C1 = enfant.CFrame:ToObjectSpace(pivot)
	mo.Parent = enfant
end

-- Squelette (positions locales : x = droite du monstre, y = haut, -z = devant)
local HANCHE_Y = 7.3
hrp.Size = Vector3.new(2, 2, 1)
hrp.CFrame = CFl(Vector3.new(0, HANCHE_Y, 0))
hrp.Transparency = 1
hrp.CanCollide = false
hrp.Anchored = false
local corps = os_("Corps", Vector3.new(0, HANCHE_Y, 0))
local hancheG = os_("HancheG", Vector3.new(-0.5, HANCHE_Y, 0))
local hancheD = os_("HancheD", Vector3.new(0.5, HANCHE_Y, 0))
local genouG = os_("GenouG", Vector3.new(-0.62, 4.75, -0.75))
local genouD = os_("GenouD", Vector3.new(0.62, 4.75, -0.75))
local tronc = os_("Tronc", Vector3.new(0, 7.9, 0.05))
local epauleG = os_("EpauleG", Vector3.new(-1.0, 10.95, -1.35))
local epauleD = os_("EpauleD", Vector3.new(1.0, 10.95, -1.35))
local coudeG = os_("CoudeG", Vector3.new(-1.42, 8.15, -1.2))
local coudeD = os_("CoudeD", Vector3.new(1.42, 8.15, -1.2))
local cou = os_("Cou", Vector3.new(0, 11.2, -1.5))
local NUQUE = Vector3.new(0, 12.2, -2.9)          -- haut du cou : pivot de la tête
local CENTRE_TETE = Vector3.new(0, 12.58, -3.15)
local tete = os_("Tete", CENTRE_TETE)              -- os de la tête = hauteur des yeux (vue du serveur)

moteur(hrp, corps)
moteur(corps, hancheG); moteur(corps, hancheD)
moteur(hancheG, genouG); moteur(hancheD, genouD)
moteur(corps, tronc)
moteur(tronc, epauleG); moteur(tronc, epauleD)
moteur(epauleG, coudeG); moteur(epauleD, coudeD)
moteur(tronc, cou)
moteur(cou, tete, NUQUE)

---------------------------------------------------------------- jambes (genoux en avant, pieds longs)
for _, cote in { { "G", -1, hancheG, genouG }, { "D", 1, hancheD, genouD } } do
	local n, sx, h, g = cote[1], cote[2], cote[3], cote[4]
	local hanche = Vector3.new(0.5 * sx, HANCHE_Y, 0)
	local genou = Vector3.new(0.62 * sx, 4.75, -0.75)
	local cheville = Vector3.new(0.72 * sx, 0.5, 0.25)
	cylindre("Cuisse" .. n, h, hanche, genou, 0.23)
	ellipsoide("CuisseMuscle" .. n, h, hanche:Lerp(genou, 0.3), Vector3.new(0.64, 1.7, 0.66), RX(-6))
	boule("Rotule" .. n, g, genou + Vector3.new(0, 0, -0.08), 0.38, PEAU)
	cylindre("Tibia" .. n, g, genou, cheville, 0.17)
	ellipsoide("Mollet" .. n, g, genou:Lerp(cheville, 0.28) + Vector3.new(0, 0, 0.06), Vector3.new(0.44, 1.7, 0.48), RX(5))
	boule("Cheville" .. n, g, cheville, 0.26, PEAU)
	ellipsoide("Pied" .. n, g, Vector3.new(0.74 * sx, 0.2, -0.55), Vector3.new(0.46, 0.34, 2.3))
	for i, dx in { -0.14, 0, 0.14 } do
		local depart = Vector3.new(0.74 * sx + dx, 0.12, -1.4)
		local bout = Vector3.new(0.74 * sx + dx * 1.8, 0.05, -2.75 + math.abs(dx) * 1.6)
		cylindre("Orteil" .. n .. i, g, depart, bout, 0.055, PEAU_SOMBRE)
	end
end

---------------------------------------------------------------- bassin, ventre
ellipsoide("Bassin", corps, Vector3.new(0, 7.62, 0.05), Vector3.new(1.35, 0.8, 0.75))
ellipsoide("IliaqueG", corps, Vector3.new(-0.55, 7.9, -0.05), Vector3.new(0.3, 0.42, 0.5), nil, PEAU)
ellipsoide("IliaqueD", corps, Vector3.new(0.55, 7.9, -0.05), Vector3.new(0.3, 0.42, 0.5), nil, PEAU)
ellipsoide("Abdomen", tronc, Vector3.new(0, 8.55, -0.15), Vector3.new(0.78, 1.4, 0.55), RX(-20), PEAU_SOMBRE)

---------------------------------------------------------------- cage thoracique (dos voûté, penchée en avant)
local CENTRE_TORSE = Vector3.new(0, 9.85, -0.72)
local ROT_TORSE = RX(-30)
local cfTorse = CFrame.new(CENTRE_TORSE) * ROT_TORSE
ellipsoide("CageThoracique", tronc, CENTRE_TORSE, Vector3.new(1.6, 2.1, 1.0), ROT_TORSE)
ellipsoide("Dos", tronc, Vector3.new(0, 10.55, -0.55), Vector3.new(1.3, 1.6, 0.9), RX(-42), PEAU_SOMBRE)
local NB_COTES = 6
for i = 1, NB_COTES do
	local yc = 0.72 - (i - 1) * 0.3
	local f = 1 - 0.22 * ((yc + 0.15) / 0.9) ^ 2
	local a, c = 0.88 * f, 0.56 * f
	local precedent = nil
	local SEG = 8
	for k = 0, SEG do
		local th = rad(-150 + 300 * k / SEG)
		local chute = -0.2 * (math.cos(th) + 1) / 2 -- les côtes descendent vers l'avant
		local pl = cfTorse * Vector3.new(a * math.sin(th), yc + chute, -c * math.cos(th))
		if precedent then
			cylindre(("Cote%d_%d"):format(i, k), tronc, precedent, pl, 0.055, COTE)
		end
		precedent = pl
	end
end
cylindre("Sternum", tronc, cfTorse * Vector3.new(0, 0.85, -0.5), cfTorse * Vector3.new(0, -0.35, -0.53), 0.07, COTE)
cylindre("ClaviculeG", tronc, Vector3.new(-0.05, 11.12, -1.55), Vector3.new(-1.0, 11.02, -1.4), 0.09, COTE)
cylindre("ClaviculeD", tronc, Vector3.new(0.05, 11.12, -1.55), Vector3.new(1.0, 11.02, -1.4), 0.09, COTE)
boule("ArticulationEpauleG", epauleG, Vector3.new(-1.0, 10.95, -1.35), 0.44, PEAU)
boule("ArticulationEpauleD", epauleD, Vector3.new(1.0, 10.95, -1.35), 0.44, PEAU)

-- colonne vertébrale saillante (crêtes dorsales) : courbe du bassin à la nuque
local function bezier(p0, p1, p2, t)
	return p0:Lerp(p1, t):Lerp(p1:Lerp(p2, t), t)
end
local D0, D1, D2 = Vector3.new(0, 8.1, 0.36), Vector3.new(0, 10.4, 0.45), Vector3.new(0, 11.35, -1.15)
local NB_VERT = 11
for i = 1, NB_VERT do
	local t = (i - 0.5) / NB_VERT
	local p = bezier(D0, D1, D2, t)
	local tangente = (bezier(D0, D1, D2, math.min(1, t + 0.02)) - bezier(D0, D1, D2, math.max(0, t - 0.02))).Unit
	local angle = math.deg(math.atan2(-tangente.Z, tangente.Y))
	local taille = 0.9 + 0.35 * math.sin(t * math.pi)
	ellipsoide("Vertebre" .. i, tronc, p, Vector3.new(0.26, 0.24, 0.42) * taille, RX(-angle), PEAU_SOMBRE)
end

---------------------------------------------------------------- cou (long, penché en avant)
local BASE_COU = Vector3.new(0, 11.2, -1.5)
cylindre("CouOs", cou, BASE_COU, NUQUE, 0.15, PEAU)
cylindre("TendonG", cou, BASE_COU + Vector3.new(-0.13, -0.05, -0.12), NUQUE + Vector3.new(-0.08, -0.12, -0.06), 0.055, PEAU_SOMBRE)
cylindre("TendonD", cou, BASE_COU + Vector3.new(0.13, -0.05, -0.12), NUQUE + Vector3.new(0.08, -0.12, -0.06), 0.055, PEAU_SOMBRE)
for i = 1, 4 do
	local p = BASE_COU:Lerp(NUQUE, (i - 0.5) / 4) + Vector3.new(0, 0.13, 0.11)
	ellipsoide("VertebreCou" .. i, cou, p, Vector3.new(0.18, 0.16, 0.3), RX(-50), PEAU_SOMBRE)
end

---------------------------------------------------------------- tête : masque pâle + long cône noir
local ROT_TETE = RX(12) -- menton en avant, cône penché vers l'arrière
local cfTete = CFrame.new(CENTRE_TETE) * ROT_TETE
ellipsoide("Crane", tete, CENTRE_TETE, Vector3.new(0.96, 1.5, 1.06), ROT_TETE, MASQUE, MAT_MASQUE)
ellipsoide("Menton", tete, cfTete * Vector3.new(0, -0.5, -0.04), Vector3.new(0.56, 0.78, 0.8), ROT_TETE, MASQUE, MAT_MASQUE)
local CERNE = Color3.fromRGB(112, 106, 102)
for _, o in { { "G", -1 }, { "D", 1 } } do
	-- cerne gris (ombre de l'orbite), puis l'orbite noire mate enfoncée dans le masque
	-- (yeux rouges en option : attribut Yeux, lu par AnimationMonstre.client)
	ellipsoide("Cerne" .. o[1], tete, cfTete * Vector3.new(0.19 * o[2], 0.05, -0.36), Vector3.new(0.44, 0.5, 0.3), ROT_TETE, CERNE, MAT_MASQUE)
	ellipsoide("Orbite" .. o[1], tete, cfTete * Vector3.new(0.19 * o[2], 0.05, -0.385), Vector3.new(0.36, 0.42, 0.28), ROT_TETE, NOIR, Enum.Material.Fabric)
end
-- cône : tranches de cylindre de plus en plus fines
local ROT_CONE = RX(18)
local baseCone = cfTete * Vector3.new(0, 0.32, 0.1)
local axe = (CFrame.new() * ROT_CONE).UpVector
local HAUT_CONE, R_CONE, TRANCHES = 3.5, 0.52, 24
for i = 1, TRANCHES do
	local t0, t1 = (i - 1) / TRANCHES, i / TRANCHES
	local r = R_CONE * (1 - (t0 + t1) / 2)
	cylindre("Cone" .. i, tete, baseCone + axe * HAUT_CONE * t0, baseCone + axe * HAUT_CONE * (t1 + 0.02), math.max(r, 0.025), CONE, MAT_CONE)
end

---------------------------------------------------------------- bras très longs, mains énormes
for _, cote in { { "G", -1, epauleG, coudeG }, { "D", 1, epauleD, coudeD } } do
	local n, sx, e, c = cote[1], cote[2], cote[3], cote[4]
	local epaule = Vector3.new(1.0 * sx, 10.95, -1.35)
	local coude = Vector3.new(1.42 * sx, 8.15, -1.2)
	local poignet = Vector3.new(1.72 * sx, 4.95, -1.0)
	cylindre("Bras" .. n, e, epaule, coude, 0.16)
	ellipsoide("Biceps" .. n, e, epaule:Lerp(coude, 0.35), Vector3.new(0.42, 1.5, 0.44))
	boule("ArticulationCoude" .. n, c, coude, 0.3, PEAU)
	cylindre("AvantBras" .. n, c, coude, poignet, 0.13)
	ellipsoide("AvantBrasMuscle" .. n, c, coude:Lerp(poignet, 0.25), Vector3.new(0.34, 1.5, 0.36))
	boule("Poignet" .. n, c, poignet, 0.22, PEAU)
	-- paume tournée vers la cuisse
	local paume = poignet + Vector3.new(0.04 * sx, -0.58, 0)
	ellipsoide("Main" .. n, c, paume, Vector3.new(0.26, 1.3, 0.88))
	local doigts = { { -0.34, 1.7 }, { -0.13, 2.15 }, { 0.08, 2.25 }, { 0.28, 1.9 } }
	for i, dg in doigts do
		local dz, long = dg[1], dg[2]
		local racine = paume + Vector3.new(0, -0.5, dz)
		local milieu = racine + Vector3.new(0.05 * sx, -long * 0.5, dz * 0.4 - 0.05)
		local bout = milieu + Vector3.new(-0.12 * sx, -long * 0.5, dz * 0.3 - 0.18) -- se recourbe
		cylindre("Doigt" .. n .. i, c, racine, milieu, 0.075, PEAU_SOMBRE)
		cylindre("Griffe" .. n .. i, c, milieu, bout, 0.05, NOIR)
	end
	local rp = paume + Vector3.new(-0.02 * sx, -0.05, -0.3)
	local mp = rp + Vector3.new(-0.05 * sx, -0.55, -0.15)
	cylindre("Pouce" .. n, c, rp, mp, 0.06, PEAU_SOMBRE)
	cylindre("GriffePouce" .. n, c, mp, mp + Vector3.new(-0.08 * sx, -0.5, 0.05), 0.04, NOIR)
end

---------------------------------------------------------------- filaments noirs qui pendent
local FIL = Color3.fromRGB(14, 12, 12)
local function filament(nom, os, depart, longueur, derive)
	cylindre(nom, os, depart, depart + Vector3.new(derive.X, -longueur, derive.Z), 0.025, FIL, Enum.Material.SmoothPlastic)
end
local filsTete = {
	{ Vector3.new(-0.3, -0.25, 0.25), 1.4, Vector3.new(-0.1, 0, 0.15) },
	{ Vector3.new(0.32, -0.2, 0.2), 1.1, Vector3.new(0.12, 0, 0.1) },
	{ Vector3.new(-0.15, -0.4, 0.35), 1.9, Vector3.new(0, 0, 0.2) },
	{ Vector3.new(0.18, -0.38, 0.32), 1.6, Vector3.new(0.05, 0, 0.25) },
	{ Vector3.new(0.38, -0.05, 0.1), 0.9, Vector3.new(0.15, 0, 0) },
}
for i, f in filsTete do
	filament("FilTete" .. i, tete, cfTete * f[1], f[2], f[3])
end
local filsCou = {
	{ 0.3, Vector3.new(-0.16, 0, 0), 1.3 }, { 0.5, Vector3.new(0.17, 0, 0.05), 1.0 },
	{ 0.75, Vector3.new(-0.14, 0, 0.05), 0.8 }, { 0.9, Vector3.new(0.12, 0, 0), 1.5 },
}
for i, f in filsCou do
	filament("FilCou" .. i, cou, BASE_COU:Lerp(NUQUE, f[1]) + f[2], f[3], Vector3.new(f[2].X * 0.5, 0, 0.1))
end
for _, cote in { { "G", -1, coudeG }, { "D", 1, coudeD } } do
	local n, sx, c = cote[1], cote[2], cote[3]
	filament("FilBras" .. n .. "1", c, Vector3.new(1.62 * sx, 5.9, -1.05), 3.8, Vector3.new(0.1 * sx, 0, 0.1))
	filament("FilBras" .. n .. "2", c, Vector3.new(1.55 * sx, 6.7, -1.12), 4.3, Vector3.new(0.05 * sx, 0, -0.1))
	filament("FilBras" .. n .. "3", c, Vector3.new(1.7 * sx, 5.2, -0.95), 3.2, Vector3.new(0.18 * sx, 0, 0.15))
end
filament("FilHancheG", corps, Vector3.new(-0.55, 7.7, 0.15), 2.2, Vector3.new(-0.1, 0, 0.1))
filament("FilHancheD", corps, Vector3.new(0.6, 7.75, 0.1), 1.6, Vector3.new(0.1, 0, 0.1))

---------------------------------------------------------------- Humanoid
hum.AutomaticScalingEnabled = false
hum.RigType = Enum.HumanoidRigType.R15
hum.HipHeight = HANCHE_Y * S - hrp.Size.Y / 2
m.PrimaryPart = hrp
for _, p in tampon:GetChildren() do
	p.Parent = m
end
tampon:Destroy()
if m:GetAttribute("Yeux") == nil then
	m:SetAttribute("Yeux", "noirs")
end
local cf, taille = m:GetBoundingBox()
local basY = math.huge
for _, p in m:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 1 then
		basY = math.min(basY, p.Position.Y - p.Size.Y / 2)
	end
end
return ("parties=%d (+HRP) taille=%s hipHeight=%.2f bas=%.2f sommet=%.2f"):format(nbParties, tostring(taille), hum.HipHeight, basY, cf.Position.Y + taille.Y / 2)
