--!strict
--[[
	Rôle    : comment le monstre réagit à un bruit selon son STADE (1 marche ... 4 nettoyage,
	          voir Shared/Bruit/ReglagesBruit). Ne lance aucun rayon et ne bouge rien :
	          - normaliser : valide les arguments reçus par MonstreBruit et en déduit stade et portée
	                (les arguments viennent d'un BindableEvent serveur, mais on vérifie quand même) ;
	          - dureeEcoute : temps figé à écouter avant d'aller voir (court pour les gros bruits) ;
	          - vitesseEnquete : vitesse pour aller voir (rapide pour les gros bruits) ;
	          - plusFort : quel bruit l'attire le plus (stade d'abord, puis intensité).
	          Contrat de MonstreBruit:Fire(position, portee, joueur?, stade?) :
	            - avec stade (1..STADE_MAX, Server/Bruit) : bruit de corps ; portée = PORTEE_OUIE_STADE_n
	              (le paramètre portee est ignoré : c'est l'oreille du monstre qui décide) ;
	            - sans stade (Outils/Utilisations/Nettoyage) : bruit d'outil = nettoyage, stade max ;
	              portée = max(portee x MULTIPLICATEUR_NETTOYAGE, PORTEE_OUIE_STADE_max).
	          Chiffres : Monstre/Reglages.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local Players = game:GetService("Players")

export type Profil = {
	portee: number,
	ecoutePres: number,
	ecouteLoin: number,
	vitesse: number,
}

export type Bruit = {
	position: Vector3,
	portee: number,
	source: Player?,
	stade: number,
}

export type ReactionBruit = {
	stadeMax: number,
	profil: (stade: number) -> Profil,
	normaliser: (position: unknown, portee: unknown, source: unknown, stade: unknown) -> Bruit?,
	dureeEcoute: (stade: number, intensite: number) -> number,
	vitesseEnquete: (stade: number) -> number,
	plusFort: (stadeA: number, intensiteA: number, stadeB: number, intensiteB: number) -> boolean,
}

local ReactionBruit = {}

local function estFini(x: unknown): boolean
	return type(x) == "number" and x == x and math.abs(x) < 1e6
end

function ReactionBruit.nouveau(R: any, stadeMax: number): ReactionBruit
	-- profils lus une fois : une valeur manquante dans Reglages est une erreur de réglage, on le dit tout de suite
	local profils: { Profil } = {}
	for stade = 1, stadeMax do
		local function lire(prefixe: string): number
			local valeur = R[prefixe .. stade]
			assert(type(valeur) == "number", ("Reglages monstre : %s%d manquant"):format(prefixe, stade))
			return valeur
		end
		profils[stade] = table.freeze({
			portee = lire("PORTEE_OUIE_STADE_"),
			ecoutePres = lire("ECOUTE_PRES_STADE_"),
			ecouteLoin = lire("ECOUTE_LOIN_STADE_"),
			vitesse = lire("VITESSE_ENQUETE_STADE_"),
		})
	end

	local function profil(stade: number): Profil
		return profils[math.clamp(math.floor(stade), 1, stadeMax)]
	end

	local function normaliser(position: unknown, portee: unknown, source: unknown, stade: unknown): Bruit?
		if typeof(position) ~= "Vector3" then
			return nil
		end
		local p = position :: Vector3
		if not (estFini(p.X) and estFini(p.Y) and estFini(p.Z)) then
			return nil
		end
		-- source : on ne garde qu'un vrai joueur encore présent
		local joueur: Player? = nil
		if typeof(source) == "Instance" and (source :: Instance):IsA("Player") and (source :: Player).Parent == Players then
			joueur = source :: Player
		end

		local niveau: number
		local distance: number
		if type(stade) == "number" and stade == math.floor(stade) and stade >= 1 and stade <= stadeMax then
			niveau = stade
			distance = profils[niveau].portee
		else
			-- bruit d'outil : c'est un nettoyage, le plus attirant des bruits
			if not estFini(portee) or (portee :: number) <= 0 then
				return nil
			end
			niveau = stadeMax
			distance = math.max((portee :: number) * R.MULTIPLICATEUR_NETTOYAGE, profils[stadeMax].portee)
		end
		return {
			position = p,
			portee = math.clamp(distance, 0, R.PORTEE_BRUIT_MAX),
			source = joueur,
			stade = niveau,
		}
	end

	-- intensite : 1 tout près, 0 au bout de la portée
	local function dureeEcoute(stade: number, intensite: number): number
		local pr = profil(stade)
		return pr.ecoutePres + (pr.ecouteLoin - pr.ecoutePres) * (1 - math.clamp(intensite, 0, 1))
	end

	local function vitesseEnquete(stade: number): number
		return profil(stade).vitesse
	end

	-- A l'attire-t-il plus que B ? Le stade compte d'abord ; à stade égal, le bruit nettement plus fort
	local function plusFort(stadeA: number, intensiteA: number, stadeB: number, intensiteB: number): boolean
		if stadeA ~= stadeB then
			return stadeA > stadeB
		end
		return intensiteA > intensiteB + 0.1
	end

	return {
		stadeMax = stadeMax,
		profil = profil,
		normaliser = normaliser,
		dureeEcoute = dureeEcoute,
		vitesseEnquete = vitesseEnquete,
		plusFort = plusFort,
	}
end

return ReactionBruit
