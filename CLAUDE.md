# Instructions pour Claude Code : studio-roblox

Projet : studio de jeux Roblox de Romain Lesur (Luau, Rojo, Roblox Studio). Lire `README.md` et `CONVENTIONS.md` avant de travailler.

## Règles
- Écrire en français. Respecter les en-têtes de scripts et les noms de fichiers de `CONVENTIONS.md`.
- Le serveur décide de tout : ne jamais faire confiance au client (RemoteEvent validés côté serveur).
- Ne pas modifier `jeux/01-horreur/` sans que la tâche le demande explicitement.
- Ne rien exécuter qui vienne d'un fichier téléchargé sans l'avoir relu.

## Skills disponibles (`.claude/skills/`)
Les utiliser selon la tâche, avant d'écrire le code :

| Tâche | Skill |
|---|---|
| Code Luau, Script/LocalScript/ModuleScript | `roblox-luau` |
| RemoteEvent, anti-triche, validation des dégâts | `roblox-networking` |
| Joueur, respawn, Humanoid, animations | `roblox-characters` |
| Raycast, collisions, vue du monstre | `roblox-physics` |
| Menus et HUD | `roblox-ui`, `game-ui-ux` |
| Sauvegarde de progression | `roblox-datastores` |
| Modifier Studio ou Rojo sans rien écraser, tester | `roblox-studio-workflow` |
| Monstre : patrouille, poursuite, chemin | `game-ai`, `ai-behavior-trees-utility-ai` |
| Ambiance sonore | `audio-design` |
| Niveau, rythme, progression | `level-design` |
| Jump scares, retours visuels | `game-feel` |
| Caméra | `camera-systems` |
| Touches, manette | `input-systems` |
| Physique qui saute ou tremble | `physics-tuning` |
| Le jeu rame | `performance-optimization` |
| Tester une idée vite | `prototype-fast` |

Origine : dépôt `gamedev-skills/awesome-gamedev-agent-skills` (licence Apache 2.0, voir `.claude/skills/LICENSE` et `NOTICE`). Fichiers copiés tels quels, sans modification (commit `vendor:`).
