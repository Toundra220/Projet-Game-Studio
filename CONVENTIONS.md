# Conventions du dépôt

## Messages de commit
Format : `type(portée): description courte en français`

| Type | Usage | Exemple |
|---|---|---|
| `feat` | Nouvelle fonctionnalité dans un jeu | `feat(horreur): porte qui s'ouvre au contact` |
| `fix` | Correction de bug | `fix(horreur): le jumpscare se déclenchait deux fois` |
| `apprentissage` | Exercice Luau | `apprentissage: exercice 3, lumière qui clignote` |
| `vendor` | Ajout de code ou de modèle réutilisé, tel quel | `vendor: lampe torche (Toolbox, auteur X)` |
| `docs` | Documentation, conception, veille, suivis | `docs: conception du jeu 1` |
| `preuves` | Captures d'écran | `preuves: captures du 18 octobre` |

Règles :
- Un commit = une chose. Committer à la fin de chaque session de travail.
- Code réutilisé : d'abord un commit `vendor:` avec le fichier d'origine non modifié, ensuite un commit séparé pour mes modifications.
- Avant chaque `git push` : vérifier qu'aucun mot de passe, cookie Roblox ou clé d'API n'est dans les fichiers modifiés (`git diff --staged`).

## En-tête des scripts
```lua
--[[
	Rôle    : ce que fait le script
	Origine : ÉCRIT | ADAPTÉ de <source> | RÉUTILISÉ de <source>
	Auteur  : Romain Lesur
	Date    : AAAA-MM-JJ
]]
```

## Noms de fichiers (Rojo)
- `Nom.server.luau` : Script côté serveur
- `Nom.client.luau` : LocalScript côté joueur
- `Nom.luau` : ModuleScript

## Captures
`preuves/AAAA-MM/AAAA-MM-JJ_description.png`, sans e-mail ni information personnelle visible.
