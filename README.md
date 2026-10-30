# Studio de jeux Roblox : Romain Lesur

Projet Personnel et Professionnel (PPP), L3 SDN, octobre 2026 à mai 2027.
Je crée et publie plusieurs jeux Roblox, je les fais connaître sur TikTok et Instagram et je pilote le tout comme une petite entreprise, avec des chiffres.

## Liens
| Quoi | Lien |
|---|---|
| Jeu 1 (horreur) | à venir (fin novembre 2026) |
| Groupe Roblox du studio | à compléter |
| TikTok | à compléter |
| Instagram | à compléter |
| Tableau Kanban | https://github.com/users/Toundra220/projects/3 |

## État d'avancement
| Mois | Objectif | État |
|---|---|---|
| Octobre 2026 | Prise en main de Studio et Luau, conception du jeu 1 | en cours |
| Novembre 2026 | Construction et publication du jeu 1 | à venir |

## Organisation du dépôt
| Dossier | Contenu |
|---|---|
| `docs/` | Cahier des charges, conception des jeux, veille, choix d'architecture |
| `apprentissage/` | Exercices Luau et journal d'apprentissage (`JOURNAL_LUAU.md`) |
| `jeux/` | Code source de chaque jeu, synchronisé avec Roblox Studio par Rojo |
| `suivis/` | Documents de suivi mensuels |
| `preuves/` | Captures d'écran datées, classées par mois |
| `JOURNAL.md` | Journal de bord : une ligne par session de travail |
| `CREDITS.md` | Tout ce que j'ai réutilisé (modèles, sons, code) et sa source |

## Code écrit ou réutilisé
Chaque script commence par un en-tête `Origine : ÉCRIT`, `ADAPTÉ de <source>` ou `RÉUTILISÉ de <source>`.
Le code réutilisé est rangé dans `vendor/` et ajouté tel quel dans un commit à part, avant toute modification : l'historique Git montre donc précisément ce que j'ai écrit moi-même.

## Travailler sur un jeu
1. Installer [Rokit](https://github.com/rojo-rbx/rokit), puis `rokit install` à la racine du dépôt.
2. Installer le plugin Rojo dans Roblox Studio.
3. `cd jeux/01-horreur` puis `rojo serve`, et cliquer sur « Connect » dans le plugin Rojo de Studio.

Les fichiers `.rbxl` ne sont pas versionnés (voir `.gitignore`) : la map est sauvegardée dans le cloud Roblox, le code est ici.
