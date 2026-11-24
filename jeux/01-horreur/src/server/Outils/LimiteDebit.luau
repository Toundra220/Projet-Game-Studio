--!strict
--[[
	Rôle    : limiteur de débit par joueur (seau à jetons), pour empêcher qu'un joueur
	          spamme un RemoteEvent. Chaque joueur a un seau qui se remplit tout seul.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

export type LimiteDebit = {
	consommer: (joueur: Player, cout: number?) -> boolean,
	oublier: (joueur: Player) -> (),
}

type Seau = { jetons: number, dernierTemps: number }

local LimiteDebitModule = {}

-- capacite : nombre de jetons max (taille de la « rafale » permise)
-- rechargeParSeconde : jetons rendus par seconde
function LimiteDebitModule.nouveau(capacite: number, rechargeParSeconde: number): LimiteDebit
	local seaux: { [Player]: Seau } = {}

	local function consommer(joueur: Player, cout: number?): boolean
		local prix = cout or 1
		local maintenant = os.clock()
		local seau = seaux[joueur]
		if not seau then
			seau = { jetons = capacite, dernierTemps = maintenant }
			seaux[joueur] = seau
		end
		-- recharge proportionnelle au temps écoulé, sans dépasser la capacité
		local ecoule = maintenant - seau.dernierTemps
		seau.jetons = math.min(capacite, seau.jetons + ecoule * rechargeParSeconde)
		seau.dernierTemps = maintenant

		if seau.jetons < prix then
			return false
		end
		seau.jetons -= prix
		return true
	end

	local function oublier(joueur: Player)
		seaux[joueur] = nil
	end

	return { consommer = consommer, oublier = oublier }
end

return LimiteDebitModule
