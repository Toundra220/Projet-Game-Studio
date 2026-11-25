# Instructions pour Claude Code : studio-roblox

Projet : studio de jeux Roblox de Romain Lesur (Luau, Rojo, Roblox Studio). Lire `README.md` et `CONVENTIONS.md` avant de travailler.

## Règles
- Écrire en français. Respecter les en-têtes de scripts et les noms de fichiers de `CONVENTIONS.md`.
- Le serveur décide de tout : ne jamais faire confiance au client (RemoteEvent validés côté serveur).
- Ne pas modifier `jeux/01-horreur/` sans que la tâche le demande explicitement.
- Ne rien exécuter qui vienne d'un fichier téléchargé sans l'avoir relu.

## Coffre Obsidian (mémoire du projet) : À LIRE EN PREMIER
Chemin : `C:\Users\user\OneDrive - Institut Catholique de Lille\Documents\Roblox-Game\`
Ce coffre contient ce qu'on sait de NOTRE jeu (les skills disent comment faire en général, le coffre dit comment on le fait ici).

Au début de chaque session :
1. Lire `00-Accueil.md`, puis seulement les fiches liées à la tâche (ne pas tout charger).
2. Avant une pièce, un objet ou un modèle : lire `01-Conception/Plan-du-manoir.md` et `06-Styles-valides/DA-Manoir.md` (regarder les images citées).
3. Avant le monstre : `01-Conception/Monstre.md` et `03-Code-Luau/Script-MonstreIA.md`.
4. Pour formuler et tester : `07-Methode/Regles-de-prompt.md`.

Pendant et après :
- Si une info du coffre contredit le dépôt ou Studio, le signaler au lieu de choisir seul.
- Quand Romain valide un résultat, proposer une fiche dans `06-Styles-valides/` (prompt exact, réglages, capture) et mettre à jour la fiche concernée (réglages, état du code).
- Marquer `(non vérifié)` ce qui n'est pas sûr. Ne jamais inventer un ID d'asset ou une API.
- Le coffre est hors du dépôt : rien n'y est commité ; ne pas y copier de clé ou d'info personnelle.

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
| Structurer ou refactorer un système (SOLID) | `solid-luau` |

Origine : dépôt `gamedev-skills/awesome-gamedev-agent-skills` (licence Apache 2.0, voir `.claude/skills/LICENSE` et `NOTICE`). Fichiers copiés tels quels, sans modification (commit `vendor:`). Exception : `solid-luau` est écrit pour ce projet (pas couvert par ce `NOTICE`).
