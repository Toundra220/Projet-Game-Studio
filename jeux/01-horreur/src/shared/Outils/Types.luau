--!strict
--[[
	Rôle    : types partagés (client et serveur) du système d'outils ramassables
	          (balai, aspirateur) : définitions, paiement, sessions d'utilisation,
	          stratégies, détecteur et affichage. Aucun code : uniquement des types.
	Origine : ÉCRIT PAR CLAUDE
	Auteur  : Romain Lesur
	Date    : 2026-11-24 (modifié : 2026-11-25, vitesseNettoyage)
]]

-- Bruit envoyé au monstre pendant l'utilisation d'un outil.
-- portee : studs (multipliée par l'attribut FacteurBruit de la tache) ; periode : secondes entre deux bruits
export type Bruit = { portee: number, periode: number }

export type DefinitionOutil = {
	id: string,
	nomAffiche: string,
	article: string,             -- "le balai", "l'aspirateur"
	payant: boolean,             -- true = acheté en Robux (game pass)
	idGamePass: number,          -- 0 = pas encore créé (À REMPLIR par Romain) ; ignoré si payant = false
	utilisation: string,         -- clé de stratégie serveur, ex. "Nettoyage"
	animation: string,           -- clé de forme client, ex. "Balayage"
	verbeUtilisation: string,    -- "Balayer", "Aspirer"
	tagCible: string,            -- "Nettoyable"
	dureeUtilisation: number,    -- secondes pour nettoyer une cible qui n'a pas de durée propre (attribut DureeNettoyage)
	vitesseNettoyage: number,    -- 1 = comme le balai ; 1,6 = 1,6 fois plus vite. Divise la DureeNettoyage de la cible
	porteeUtilisation: number,   -- studs
	bruit: Bruit?,               -- bruit envoyé au monstre pendant l'utilisation (nil = silencieux)
	prise: CFrame?,              -- Tool.Grip : comment la main tient l'objet (nil = prise par défaut)
}

-- Paiement (Robux, game pass). Interface asynchrone, serveur uniquement.
export type RappelAchat = (joueur: Player, definition: DefinitionOutil) -> ()

export type Paiement = {
	nom: string,
	-- le joueur possède déjà l'achat ? (peut attendre : appel Marketplace dans pcall, résultat mis en cache)
	possede: (joueur: Player, definition: DefinitionOutil) -> boolean,
	-- le serveur ouvre la fenêtre d'achat chez le joueur. false + code si impossible :
	-- "achat_non_configure" (idGamePass = 0) ou "achat_indisponible" (erreur Roblox)
	proposerAchat: (joueur: Player, definition: DefinitionOutil) -> (boolean, string?),
	-- enregistre la fonction appelée quand un achat est confirmé côté serveur
	surAchatConfirme: (rappel: RappelAchat) -> (),
	-- et quand le joueur ferme la fenêtre sans acheter
	surAchatAnnule: (rappel: RappelAchat) -> (),
}

export type SessionUtilisation = {
	joueur: Player,
	outil: Tool,
	definition: DefinitionOutil,
	cible: Instance,
	debut: number,
	donnees: { [string]: any },
}

export type ResultatAvance = "continue" | "fini"

export type StrategieUtilisation = {
	commencer: (session: SessionUtilisation) -> (boolean, string?),
	avancer: (session: SessionUtilisation, dt: number) -> ResultatAvance,
	finir: (session: SessionUtilisation, raison: string) -> (), -- "fini" | "arret" | "invalide" | "depart"
}

export type Detecteur = { chercher: () -> Instance? }

export type Affichage = {
	afficher: (cible: Instance, texte: string) -> (),
	masquer: () -> (),
	detruire: () -> (),
}

return {}
