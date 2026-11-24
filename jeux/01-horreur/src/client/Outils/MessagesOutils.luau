--!strict
--[[
	Rôle    : textes français des codes envoyés par le serveur (RetourOutil).
	          Un code inconnu donne un texte vide (rien n'est affiché).
	          Les textes avec « %s » reçoivent l'article de l'outil (« le balai »).
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Partage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Outils")
local Types = require(Partage:WaitForChild("Types"))

local MESSAGES: { [string]: string } = table.freeze({
	ramasse = "Tu as ramassé %s.",
	achete = "Merci ! Tu as maintenant %s.",
	achat_propose = "",
	achat_annule = "Achat annulé.",
	achat_indisponible = "Achat indisponible pour le moment.",
	deja_possede = "Tu as déjà %s.",
	indisponible = "Cet objet n'est plus disponible.",
	trop_loin = "Trop loin.",
	pas_visible = "Tu ne vois pas l'objet.",
	mauvais_outil = "Il te faut le bon outil.",
	utilisation_fini = "C'est propre !",
	utilisation_arretee = "",
})

local MessagesOutils = {}

MessagesOutils.messages = MESSAGES

-- Texte final pour un code. La définition (si connue) fournit l'article.
function MessagesOutils.texte(code: string, definition: Types.DefinitionOutil?): string
	local modele = MESSAGES[code]
	if modele == nil then
		return ""
	end
	if string.find(modele, "%%s") then
		local article = if definition then definition.article else "l'objet"
		return string.format(modele, article)
	end
	return modele
end

return table.freeze(MessagesOutils)
