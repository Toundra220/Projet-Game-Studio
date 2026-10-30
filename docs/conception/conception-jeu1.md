# Conception du jeu 1 : jeu d'horreur dans un manoir

Auteur : Romain Lesur. Version 0.6 du 28/10/2026 (brouillon, à compléter).

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

## 5. La map : plan du manoir (dessiné le 30/10/2026)
Le plan dessiné à la main est dans `docs/conception/` (photo). Le manoir a deux niveaux.

**Rez-de-chaussée** : un grand couloir central relie toutes les pièces.
- Rangée du haut : salle de vie, cuisine, stockage, escalier, garage.
- Rangée du bas : salle à manger, entrée (au milieu, en bas), WC, salle de bains.

**Étage** : escalier en haut au centre.
- 2 chambres, 2 salles de jeux, une salle de bain avec WC, une salle de stockage.

```
        REZ-DE-CHAUSSÉE
 [Salle de vie][Cuisine][Stockage][Escalier][   Garage   ]
 [            C O U L O I R                              ]
 [Salle à manger]  [ENTRÉE]            [WC][Salle de bains]

        ÉTAGE
 [Chambre][ Escalier ][Salle de jeux]
 [Salle de bain + WC][Salle stockage][Chambre][Salle de jeu]
```

- **Nombre de pièces :** 9 au rez-de-chaussée, 8 à l'étage (à simplifier pour novembre : garder les pièces utiles aux tâches, les autres peuvent rester fermées).
- **Ambiance :** lumière faible, ombres, sons de vent et de craquements, meubles simples (peu de détails, comme Monochrome).
- **Départ du joueur :** à l'entrée, au rez-de-chaussée.
- **Départ du monstre :** il apparaît dans une chambre de l'étage et commence à se déplacer 7 secondes après le début de la partie.
- **Sortie finale (décidé) :** la porte d'entrée, en bas du plan. Une fois toutes les tâches finies, le joueur doit retraverser le couloir pour sortir, avec le monstre qui peut arriver.
- **Aspirateur :** dans une pièce de stockage (rez-de-chaussée ou étage, à décider).

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
