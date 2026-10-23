# Conception du jeu 1 : jeu d'horreur dans un manoir

Auteur : Romain Lesur. Version 0.5 du 23/10/2026 (brouillon, à compléter).

## 1. Pitch
Le joueur doit nettoyer un manoir le plus vite possible pour terminer la partie. Un monstre rôde dans le manoir : il faut l'esquiver tout en finissant les tâches de ménage.

## 2. Objectif et boucle de jeu
- **Objectif :** terminer toutes les tâches de nettoyage avant de sortir, le plus rapidement possible.
- **Danger :** un monstre dans le manoir, à esquiver.
- **Boucle :** choisir une tâche, aller dans la pièce, la faire, repérer ou éviter le monstre, passer à la suivante, terminer la liste, sortir.
- **Vies :** 3 vies. Quand le monstre attrape le joueur, il perd une vie mais reprend là où il en était (pas de retour au début). À la troisième vie perdue, la partie est à recommencer entièrement.
- **Fin de partie :** temps final affiché à la sortie (à compléter : score, classement ?).

## 3. Tâches (à définir)
| Pièce | Tâche | Interaction |
|---|---|---|
| Sol (plusieurs pièces) | Nettoyer les saletés au sol | Rester sur la saleté ou cliquer dessus jusqu'à ce qu'elle disparaisse |
| Murs | Nettoyer les taches sur le mur | Même principe que le sol, sur un mur |
| Rangement (pièce à définir) | Aller chercher l'aspirateur | Ramasser l'objet, qui apparaît ensuite dans l'inventaire |
| Pièces avec miettes | Aspirer les miettes sur les meubles | Utiliser l'aspirateur sur les zones de miettes |
| À compléter | À compléter | À compléter |

Nombre de tâches pour finir : à décider (idée : 8 à 12, pour une partie de 5 à 10 minutes).

## 4. Le monstre (à définir)
- **Nom / apparence :** un lutin, très grand et très fin, inspiré de l'analog horror et de la créature « sauterelle » qui marche bien sur Roblox (silhouette longue, jambes fines, tête pointue). Je le modélise moi-même : il ne reprend pas directement l'image d'un autre créateur (voir « Règles sur les références » plus bas). Nom à trouver :
- **Déplacement et détection (décidé) :** le monstre se déplace en fonction du bruit produit par le joueur. Le bruit l'attire vers l'endroit où il a été fait. S'il voit le joueur dans son champ de vision, il le poursuit à pleine vitesse.
- **États du monstre :** (1) en attente ou patrouille calme, (2) il va vers un bruit entendu, (3) il poursuit le joueur qu'il voit, (4) il perd le joueur et retourne en patrouille.
- **Sources de bruit à prévoir :** courir, utiliser l'aspirateur (bruyant), ramasser ou poser un objet. Marcher accroupi ou lentement est silencieux. Le choix de ce qui fait du bruit crée le gameplay : l'aspirateur est utile mais attire le monstre.
- **Signaux au joueur :** son d'approche audible de loin, son différent quand il repère le joueur, yeux rouges (idées issues de la veille).
- **Quand il attrape le joueur :** le joueur perd une vie et reprend sa progression. À 0 vie, la partie recommence depuis le début.

## 5. La map : plan du manoir (à confirmer)
Le manoir a deux niveaux. Au rez-de-chaussée, un grand hall central avec l'entrée, qui dessert les pièces à gauche et à droite.

**Rez-de-chaussée**
- **Hall central (entrée) :** grande allée au milieu, point de départ du joueur.
- **Côté gauche :** une grande salle à manger avec une longue table ovale, puis une salle de vie avec télévision.
- **Côté droit :** une salle de bain, une salle de stockage (idée : l'aspirateur s'y trouve) et des toilettes.

**Étage**
- 3 chambres, une autre salle de bain et d'autres toilettes. L'escalier est au milieu, au fond du hall.

```
        ÉTAGE
  [Chambre][Chambre][Chambre]   [Salle de bain][WC]
  --------------- couloir ---------------

        REZ-DE-CHAUSSÉE
  [Salle à manger]  |  HALL  |  [Salle de bain]
  [table ovale   ]  |  (entrée) | [Stockage]
  [Salle de vie  ]  |        |  [Toilettes]
  [télé          ]  |        |
```

- **Nombre de pièces :** environ 10 à 12 au total (à ajuster pour rester faisable en novembre).
- **Schéma dessiné :** à ajouter dans `docs/conception/` (photo d'un dessin à main levée).
- **Ambiance :** lumière faible, ombres, sons de vent et de craquements, meubles simples (peu de détails, comme Monochrome).
- **Escalier :** au milieu, au fond du hall.
- **Départ du joueur :** au rez-de-chaussée (à confirmer : dans le hall ?).
- **Départ du monstre :** il apparaît dans une des chambres de l'étage et commence à se déplacer 7 secondes après le début de la partie. Ça laisse au joueur un petit temps pour comprendre et commencer sa première tâche.
- **Question ouverte :** où est la sortie finale (idée : la porte d'entrée du hall).

## 6. Ce que je reprends de ma veille
- Monochrome : map courte avec peu de détails, un seul danger, un objectif clair.
- Lotus : le bruit du joueur attire le monstre.
- Maloch : sons différents pour l'approche et la détection, tutoriel de départ.
- Monétisation : avantages de confort vendus à côté de la partie.

## 7. Monétisation prévue
Revives, lampes améliorées, skins (cahier des charges). À préciser :

## 8. Scripts nécessaires (niveau débutant Luau)
| Script | Rôle | Côté | Difficulté |
|---|---|---|---|
| | | | |

## 9. Planning de réalisation
- Prototype jouable :
- Test avec des amis :
- Publication : fin novembre 2026

## 10. Règles sur les références
- Je m'inspire de ce que j'ai vu (analog horror, jeux de la veille), mais je crée mon propre modèle de monstre et mes propres sons.
- Tout élément réutilisé (modèle de la Toolbox, son, image) est listé dans `CREDITS.md` avec sa source.
