--!strict
--[[
	Rôle    : la règle de l'endurance, sans Roblox autour (pas de Player, pas de Humanoid) :
	          on lui donne l'état, le temps écoulé et ce que veut le joueur, elle met l'état à jour.
	          - courir vide la jauge (1 / DUREE_JAUGE par seconde) ;
	          - à vide, la course est refusée jusqu'à SEUIL_REPRISE (évite le clignotement course/marche) ;
	          - la jauge ne se remplit qu'après DELAI_RECHARGE sans courir, puis en DUREE_RECHARGE ;
	          - à l'arrêt, on ne court pas et on ne dépense rien.
	          Facile à tester seule (ServiceSprint la branche aux joueurs).
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

export type Reglages = {
	DUREE_JAUGE: number,
	DELAI_RECHARGE: number,
	DUREE_RECHARGE: number,
	SEUIL_REPRISE: number,
}

export type Etat = {
	endurance: number,     -- 0..1
	epuise: boolean,       -- jauge vidée, pas encore remontée à SEUIL_REPRISE
	court: boolean,        -- le joueur court en ce moment (décision du serveur)
	rechargeApres: number, -- horloge à partir de laquelle la jauge se remplit
}

local DT_MAX = 0.25 -- un gros à-coup du serveur ne doit pas vider ou remplir la jauge d'un coup

local Endurance = {}

function Endurance.nouvelEtat(): Etat
	return { endurance = 1, epuise = false, court = false, rechargeApres = 0 }
end

-- Met l'état à jour. veutCourir : demande du joueur (déjà validée). enMouvement : il avance vraiment.
function Endurance.avancer(etat: Etat, reglages: Reglages, dt: number, maintenant: number, veutCourir: boolean, enMouvement: boolean)
	dt = math.clamp(dt, 0, DT_MAX)

	if etat.epuise and etat.endurance >= reglages.SEUIL_REPRISE then
		etat.epuise = false
	end

	etat.court = veutCourir and enMouvement and not etat.epuise and etat.endurance > 0

	if etat.court then
		etat.endurance = math.max(0, etat.endurance - dt / reglages.DUREE_JAUGE)
		etat.rechargeApres = maintenant + reglages.DELAI_RECHARGE
		if etat.endurance <= 0 then
			etat.epuise = true
			etat.court = false
		end
	elseif maintenant >= etat.rechargeApres then
		etat.endurance = math.min(1, etat.endurance + dt / reglages.DUREE_RECHARGE)
	end
end

return Endurance
