--!strict
--[[
	Rôle    : la demande de course du joueur, avec une action nommée (ContextActionService) :
	          - clavier : Shift (gauche ou droit : même place sur AZERTY et QWERTY) en le maintenant ;
	          - manette : clic du stick gauche (L3) en le maintenant ;
	          - mobile : bouton « Courir » créé par ContextActionService ; un appui lance la course,
	            un autre l'arrête (TACTILE_BASCULE), pour garder le pouce libre pour la caméra.
	          Ne décide rien : il prévient seulement quand l'envie de courir change. Le serveur
	          valide, tient l'endurance et fixe la vitesse.
	          L'action « avale » l'entrée (Sink) : Shift ne sert donc plus au verrouillage de la souris
	          de Roblox (mouse lock), ce qui convient à un jeu d'horreur à la caméra libre.
Origine : ÉCRIT PAR CLAUDE
Auteur  : Romain Lesur
Date    : 2026-11-25
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

export type EntreeCourse = {
	veut: () -> boolean,
	relacher: () -> (),  -- annule la demande (jauge vide, mort, respawn) sans toucher aux touches
	arreter: () -> (),
}

local EntreeCourse = {}

-- surChangement(veutCourir) : appelé seulement quand la demande change
function EntreeCourse.demarrer(reglages: any, surChangement: (boolean) -> ()): EntreeCourse
	local veut = false

	local function definir(valeur: boolean)
		if veut ~= valeur then
			veut = valeur
			surChangement(valeur)
		end
	end

	local function surAction(_nom: string, etat: Enum.UserInputState, objet: InputObject)
		if etat == Enum.UserInputState.Begin then
			if reglages.TACTILE_BASCULE and objet.UserInputType == Enum.UserInputType.Touch then
				definir(not veut)
			else
				definir(true)
			end
		elseif etat == Enum.UserInputState.End or etat == Enum.UserInputState.Cancel then
			-- le relâchement ne compte pas pour le bouton tactile à bascule
			if not (reglages.TACTILE_BASCULE and objet.UserInputType == Enum.UserInputType.Touch) then
				definir(false)
			end
		end
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindAction(reglages.NOM_ACTION, surAction, true, table.unpack(reglages.TOUCHES))
	ContextActionService:SetTitle(reglages.NOM_ACTION, reglages.TEXTE_BOUTON_TACTILE)
	-- à gauche du bouton de saut (en bas à droite), sans le recouvrir
	ContextActionService:SetPosition(reglages.NOM_ACTION, UDim2.new(1, -170, 1, -140))

	-- fenêtre en arrière-plan : Shift relâché ailleurs ne nous prévient pas
	local focus = UserInputService.WindowFocusReleased:Connect(function()
		definir(false)
	end)

	return {
		veut = function()
			return veut
		end,
		relacher = function()
			definir(false)
		end,
		arreter = function()
			focus:Disconnect()
			ContextActionService:UnbindAction(reglages.NOM_ACTION)
			definir(false)
		end,
	}
end

return EntreeCourse
