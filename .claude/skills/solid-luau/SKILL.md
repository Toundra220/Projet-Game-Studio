---
name: solid-luau
description: >
  Principes SOLID (responsabilité unique, ouvert/fermé, substitution de Liskov, ségrégation des
  interfaces, inversion des dépendances) appliqués au Luau de Roblox : découpage en ModuleScripts,
  types exportés comme contrats, tables de stratégies, injection des dépendances par le
  constructeur. À utiliser pour structurer ou refactorer un système (IA du monstre, outils
  ramassables, vies, HUD), quand un script fait trop de choses, quand ajouter un cas oblige à
  modifier un énorme if/elseif, ou quand un module est impossible à tester sans lancer le jeu.
  Pas pour les bases du Luau (`roblox-luau`), les RemoteEvent (`roblox-networking`) ni le choix
  FSM / behavior tree (`game-ai`).
---

<!--
	Rôle    : skill Claude Code sur les principes SOLID adaptés au Luau / Roblox
	Origine : ÉCRIT (rédigé à partir des sources listées dans references/sources.md)
	Auteur  : Romain Lesur
	Date    : 2026-11-25
-->

# Principes SOLID en Luau (Roblox)

SOLID regroupe cinq principes de conception orientée objet réunis par Robert C. Martin dans
*Design Principles and Design Patterns* (2000) ; l'acronyme a été proposé ensuite par Michael
Feathers. But commun : du code qu'on peut **modifier sans tout casser**. Martin décrit le code
qui « pourrit » par quatre symptômes : rigidité (un changement en entraîne dix), fragilité (ça
casse ailleurs), immobilité (impossible de réutiliser), viscosité (le bon geste est plus dur que
le bricolage).

Luau n'a ni classes ni interfaces, mais il a ce qu'il faut :

| Notion OO | Équivalent Luau |
|---|---|
| Classe | table + métatable (`setmetatable({}, Classe)`, `Classe.__index = Classe`) |
| Module / paquet | `ModuleScript` qui renvoie une table |
| Interface | `export type` décrivant les champs et méthodes attendus |
| Polymorphisme | deux tables qui respectent le même `type` |
| Injection de dépendances | paramètres du constructeur `new(deps)` |
| Point de composition | le `Script` serveur ou client qui fait les `require` et assemble |

## Quand l'appliquer (et quand non)

- **Oui** : systèmes qui grossissent ou vont grossir (IA du monstre, outils, tâches de ménage,
  vies, HUD), code partagé entre plusieurs scripts, code qu'on veut tester sans Play.
- **Non** : un script de 20 lignes, un exercice d'`apprentissage/`, un prototype jetable
  (`prototype-fast`). Une abstraction coûte de la lecture ; on ne la paie que si la rigidité
  coûte plus cher. Règle pratique : **factoriser au deuxième ou troisième cas réel**, pas avant.
- SOLID ne remplace pas la règle du projet : **le serveur décide de tout**. Un bon découpage ne
  doit jamais déplacer une décision (dégâts, vies, achat) vers le client.

## Workflow

1. **Lire l'existant** (`jeux/01-horreur/src/`, fiche `Script-MonstreIA` du coffre) et lister ce
   que fait chaque script, verbe par verbe.
2. **Repérer les symptômes** (tableau « Signaux d'alerte » plus bas).
3. **Choisir le plus petit changement** qui corrige un symptôme : extraire un module, remplacer
   un `if/elseif` par une table, injecter une dépendance. Un principe à la fois.
4. **Garder le comportement identique** : refactorer, puis tester dans Studio (Play, lecture de
   la Sortie) avant d'ajouter une fonctionnalité.
5. **Respecter `CONVENTIONS.md`** : en-tête de script, `Nom.luau` pour les modules,
   `Nom.server.luau` / `Nom.client.luau` pour les points d'entrée.

---

## S : principe de responsabilité unique (SRP)

> « Un module ne devrait avoir qu'une seule raison de changer. » (Martin)

« Raison de changer » = un **acteur** ou un sujet qui peut demander une modification : le
game design (règles), l'animation, le son, le réseau, l'interface. Un script qui mélange les
cinq change pour cinq raisons.

**Mauvais** : `Monstre.server.luau` qui fait tout.

```lua
-- 400 lignes : pathfinding + détection + animations + sons + dégâts + HUD
while true do
	local cible = chercherJoueurProche()           -- perception
	if cible then
		humanoid:MoveTo(cible.Position)            -- déplacement
		pisteCourse:Play()                         -- animation
		sonCri:Play()                              -- audio
		if distance < 4 then
			cible.Humanoid:TakeDamage(100)         -- règles du jeu
			remoteJumpscare:FireClient(joueur)     -- réseau / retour joueur
		end
	end
	task.wait(0.1)
end
```

**Mieux** : un module par responsabilité, un script qui assemble.

```
src/server/Monstre/
	Monstre.server.luau     -- point d'entrée : require + assemblage, aucune logique
	Perception.luau         -- vue (raycast) et ouïe : « qui je détecte ? »
	Deplacement.luau        -- PathfindingService : « comment j'y vais ? »
	Etats.luau              -- patrouille / poursuite / recherche : « que dois-je faire ? »
	Attaque.luau            -- portée, cooldown, appel au service Vies
	AnimationsMonstre.luau  -- jouer la bonne piste selon l'état
```

Test rapide : décrire le module en une phrase **sans « et »**. « Perception dit quels joueurs le
monstre détecte » : bon. « Perception détecte les joueurs et joue le cri » : à couper.

Pièges :
- Ne pas découper par type technique (« tous les `Connect` ici ») mais par raison de changer.
- Ne pas pulvériser en modules de trois lignes : la cohésion compte autant que la séparation.

---

## O : principe ouvert/fermé (OCP)

> « Les entités logicielles doivent être ouvertes à l'extension mais fermées à la
> modification. » (Bertrand Meyer, 1988, repris par Martin)

Ajouter un cas (un nouvel état du monstre, un nouvel outil, une nouvelle tâche de ménage) doit
se faire **en ajoutant du code**, pas en rouvrant une fonction qui marche déjà.

**Mauvais** : chaque nouvel état oblige à modifier la même fonction.

```lua
local function mettreAJour(monstre, dt)
	if monstre.etat == "Patrouille" then
		-- ...
	elseif monstre.etat == "Poursuite" then
		-- ...
	elseif monstre.etat == "Recherche" then
		-- ...
	end -- ajouter "Embuscade" = toucher à ce bloc et risquer de casser les autres
end
```

**Mieux** : une table d'états qui respectent le même contrat.

```lua
-- Etats.luau
export type Etat = {
	entrer: (monstre: any) -> (),
	mettreAJour: (monstre: any, dt: number) -> string?, -- renvoie le nom du prochain état, ou nil
	sortir: (monstre: any) -> (),
}

local Etats: { [string]: Etat } = {
	Patrouille = require(script.Patrouille),
	Poursuite = require(script.Poursuite),
	Recherche = require(script.Recherche),
	-- Embuscade = require(script.Embuscade),  -- extension : une ligne + un fichier
}

return Etats
```

```lua
-- Machine à états : écrite une fois, jamais rouverte pour un nouvel état
local function changerEtat(monstre, nom: string)
	local etat = Etats[nom]
	assert(etat, `État inconnu : {nom}`)
	if monstre.etatCourant then
		monstre.etatCourant.sortir(monstre)
	end
	monstre.etatCourant = etat
	etat.entrer(monstre)
end

local function mettreAJour(monstre, dt: number)
	local suivant = monstre.etatCourant.mettreAJour(monstre, dt)
	if suivant then
		changerEtat(monstre, suivant)
	end
end
```

Même idée pour les **réglages** : vitesses, portées, cooldowns dans un module `Reglages.luau`
(ou des attributs sur le modèle) plutôt qu'en dur dans la logique. On règle sans modifier.

Piège : on ne peut pas être fermé à *tout*. Choisir les axes de variation probables (nouveaux
états, nouveaux outils) et ne pas abstraire le reste.

---

## L : principe de substitution de Liskov (LSP)

> Si S est un sous-type de T, on doit pouvoir utiliser un S partout où un T est attendu sans
> que le programme se comporte mal. (Barbara Liskov, 1987 ; formalisé avec Jeannette Wing en
> 1994, « A Behavioral Notion of Subtyping »)

Ce n'est pas qu'une question de signature : c'est une question de **comportement promis**.
Les règles de Liskov et Wing :

| Règle | Ce que doit faire l'implémentation qui remplace |
|---|---|
| Préconditions | ne pas en exiger **plus** (accepter au moins les mêmes entrées) |
| Postconditions | ne pas en garantir **moins** (rendre au moins ce qui est promis) |
| Invariants | conserver ceux du contrat (ex. « `durabilite` n'est jamais négative ») |
| Contrainte d'historique | ne pas permettre de changement d'état que le contrat interdit |
| Erreurs | ne pas lever d'erreur que l'appelant n'a aucune raison d'attendre |

Exemple du projet : le balai et l'aspirateur sont deux **outils de nettoyage**.

```lua
-- OutilNettoyage.luau : le contrat
export type OutilNettoyage = {
	nom: string,
	-- Précondition : joueur valide, tache est une BasePart taguée "Tache".
	-- Postcondition : renvoie true si la tache a été nettoyée, false sinon. Ne lève jamais d'erreur.
	nettoyer: (self: OutilNettoyage, joueur: Player, tache: BasePart) -> boolean,
}
return {} -- un ModuleScript doit renvoyer exactement une valeur
```

**Violation** : l'aspirateur exige en plus que le joueur ait le game pass, et lève une erreur
sinon. Le code qui marchait avec le balai plante avec l'aspirateur (précondition renforcée).

```lua
function Aspirateur:nettoyer(joueur, tache)
	if not aPayeLeGamePass(joueur) then
		error("pas de game pass")   -- ✗ l'appelant ne s'y attend pas
	end
	-- ...
end
```

**Correction** : vérifier le droit d'utiliser l'outil **avant** de le donner (au ramassage, côté
serveur). Une fois l'outil en main, `nettoyer` respecte le contrat commun : `true`/`false`,
jamais d'erreur. L'appelant n'a jamais besoin de `if outil.nom == "Aspirateur"`.

Signes de violation : un `if typeof/nom == ...` chez l'appelant pour traiter une variante à
part ; une méthode héritée qui fait `error("non supporté")` ; une variante qui ignore
silencieusement un paramètre que le contrat déclare important.

Avec les métatables (« héritage » via `__index`), le LSP est encore plus facile à casser : une
« sous-classe » qui redéfinit une méthode doit garder les mêmes promesses. Préférer la
**composition** (un outil *a* un `Effet`, un `Son`) à des chaînes d'héritage profondes.

---

## I : principe de ségrégation des interfaces (ISP)

> « Les clients ne doivent pas dépendre de méthodes qu'ils n'utilisent pas. » (Martin)

En Luau : un module qui en `require` un autre en dépend **entièrement** ; un type trop gros
oblige chaque implémentation à fournir des méthodes vides.

**Mauvais** : un gros type « Interactif » pour tout ce qu'on peut toucher dans le manoir.

```lua
export type Interactif = {
	ramasser: (self: any, joueur: Player) -> (),
	ouvrir: (self: any, joueur: Player) -> (),
	nettoyer: (self: any, joueur: Player) -> boolean,
	allumer: (self: any, joueur: Player) -> (),
}
-- La porte doit écrire ramasser/nettoyer/allumer vides, la lampe doit écrire ouvrir vide...
```

**Mieux** : de petits contrats ciblés, combinés au besoin.

```lua
export type Ramassable = { ramasser: (self: any, joueur: Player) -> boolean }
export type Ouvrable   = { ouvrir:   (self: any, joueur: Player) -> () }
export type Allumable  = { allumer:  (self: any, joueur: Player) -> () }

-- Un objet qui fait deux choses respecte les deux types :
export type LampeTorche = Ramassable & Allumable
```

Côté Roblox, l'équivalent naturel est **CollectionService** : des tags (`Ramassable`, `Ouvrable`,
`Tache`) qu'un système dédié écoute. Le système des portes ne connaît que `Ouvrable`.

Même règle pour les **RemoteEvent** : un remote par intention claire (`DemanderRamassage`,
`DemanderNettoyage`) plutôt qu'un `RemoteAction(type, ...)` fourre-tout, plus dur à valider côté
serveur (voir `roblox-networking`).

---

## D : principe d'inversion des dépendances (DIP)

> « Les modules de haut niveau ne doivent pas dépendre des modules de bas niveau ; les deux
> doivent dépendre d'abstractions. Les abstractions ne doivent pas dépendre des détails ; les
> détails doivent dépendre des abstractions. » (Martin, 1996)

Haut niveau = les règles du jeu (« le monstre attaque le joueur le plus proche qu'il voit »).
Bas niveau = les détails (`workspace:Raycast`, `PathfindingService`, `DataStoreService`, `Sound`).

**Mauvais** : la logique d'attaque va chercher elle-même les détails.

```lua
-- Attaque.luau
local Players = game:GetService("Players")
local Vies = require(game.ServerScriptService.Vies)   -- dépendance concrète en dur

function Attaque.tenter(monstre)
	for _, joueur in Players:GetPlayers() do            -- impossible à tester sans vrais joueurs
		-- ...
		Vies.retirer(joueur, 1)
	end
end
```

**Mieux** : l'abstraction est un type, les détails sont **injectés** par le constructeur.

```lua
-- Attaque.luau (haut niveau : ne fait aucun require de service concret)
export type ServiceVies = { retirer: (joueur: Player, nombre: number) -> () }
export type Detecteur = { joueursVisibles: (origine: Vector3) -> { Player } }

export type Deps = {
	vies: ServiceVies,
	detecteur: Detecteur,
	portee: number,
	horloge: () -> number,   -- os.clock en jeu, une fausse horloge en test
}

local Attaque = {}
Attaque.__index = Attaque

function Attaque.new(deps: Deps)
	return setmetatable({ deps = deps, dernierCoup = -math.huge }, Attaque)
end

function Attaque:tenter(origine: Vector3, delai: number): boolean
	local maintenant = self.deps.horloge()
	if maintenant - self.dernierCoup < delai then
		return false
	end
	for _, joueur in self.deps.detecteur.joueursVisibles(origine) do
		self.deps.vies.retirer(joueur, 1)
		self.dernierCoup = maintenant
		return true
	end
	return false
end

return Attaque
```

```lua
-- Monstre.server.luau (point de composition : le seul endroit qui connaît les détails)
local Attaque = require(script.Parent.Attaque)
local Vies = require(script.Parent.Parent.Vies)
local Perception = require(script.Parent.Perception)

local attaque = Attaque.new({
	vies = Vies,
	detecteur = Perception.new(modeleMonstre),
	portee = 4,
	horloge = os.clock,
})
```

Bénéfices : tester `Attaque` avec un faux `vies` et un faux `detecteur` (voir le skill Studio
`rbx-unit-test`) ; remplacer la perception (raycast → cône de vision) sans toucher à l'attaque.

Pièges :
- Injection ≠ conteneur d'injection. En Roblox, passer une table au constructeur suffit ; pas
  besoin de framework.
- Ne pas injecter ce qui ne variera jamais (`math`, `Vector3`). Injecter ce qui touche le monde
  extérieur : temps, aléatoire, réseau, sauvegarde, physique, joueurs.
- L'abstraction appartient au **haut niveau** : c'est `Attaque` qui définit `ServiceVies`, pas
  `Vies` qui impose sa forme.

---

## Signaux d'alerte → principe concerné

| Symptôme dans le code | Principe | Correction typique |
|---|---|---|
| Script de plus de ~200 lignes qui mélange logique, son, animation, réseau | S | extraire un module par raison de changer |
| Ajouter un état / un outil = modifier un `if/elseif` existant | O | table de stratégies indexée par nom |
| Valeurs de réglage en dur dans la logique | O | `Reglages.luau` ou attributs |
| `if outil.nom == "X" then` chez l'appelant | L | contrat commun, vérification en amont |
| Méthode qui fait `error("non supporté")` ou reste vide | L / I | découper le type |
| Un remote générique avec un paramètre `type` | I | un remote par intention |
| `require` de services concrets au cœur de la logique, impossible à tester | D | injection par `new(deps)` |
| Modules qui se `require` mutuellement (cycle) | D / S | extraire l'abstraction partagée ou inverser le sens |

## Vérification avant de rendre

- Le comportement en jeu est identique avant / après le refactor (Play, Sortie sans nouvelle
  erreur ni avertissement).
- Chaque nouveau module a l'en-tête de `CONVENTIONS.md` et un nom Rojo correct.
- Aucune décision de jeu n'a migré vers le client.
- Dire quel principe a guidé chaque changement, et ce qui n'a **pas** été testé.

Sources et lectures : `references/sources.md`.
