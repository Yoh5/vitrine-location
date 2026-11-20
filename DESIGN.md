# Design System : Sakan

## Le monde

Un panneau « À LOUER / للكراء » peint à la main, cloué sur une façade ocre de médina. Quand des nuits sont prises,
on colle une **bande rouge « LOUÉ »** en travers, comme le font les propriétaires dans la rue. Tout le site découle
de cette image : la façade est le fond, chaque logement est une planche peinte, la bande rouge ne dit qu'une chose : **pris**.

Écarté volontairement : photos d'intérieur (la démo n'en montre aucune, le plan schématique les remplace), cartes
d'annonce arrondies à étoiles, dégradés, bleu « réservation ».

## Couleurs

| Jeton | Valeur | Rôle |
|---|---|---|
| `--facade` | `#dba83c` | Fond de page : le mur ocre. |
| `--facade-ombre` / `--facade-claire` | `#c39232` / `#e8bf63` | Barre de défilement, sélection. |
| `--planche` | `#fdfdfb` | Panneaux, fiches, calendrier. |
| `--peinture` | `#141210` | Texte, cadres de 3-4 px des planches. |
| `--peinture-douce` | `#423d36` | Texte secondaire. |
| `--rouge` | `#c41e24` | « À LOUER », prix, bande « LOUÉ », bouton d'action principal. Rien d'autre. |
| `--rouge-fonce` | `#9b151a` | Survol du rouge, statuts refusée/annulée, conflit. |
| `--nuit` | `#1c1712` | En-tête (la rue) et pied de page. |
| `--vert-ok` | `#1f6a43` | Tampon « ACCEPTÉE » seulement. |

Contrastes mesurés (WCAG) :
- peinture sur façade : 8,6:1 ;
- peinture-douce sur façade : 4,96:1, et 10,6:1 sur planche ;
- rouge sur planche : 5,8:1, et planche sur rouge : 5,8:1 ;
- vert sur planche : 6,4:1 ;
- façade sur nuit : 8,2:1 ;
- rouge foncé sur le fond de conflit `#fbe4e3` : 6,9:1.

**Règle :** une nuit prise n'est jamais signalée par la couleur seule. Elle est aussi barrée, hachurée et porte le mot « Loué ».

## Typographie

Polices auto-hébergées (`public/polices`, licences OFL jointes) ; aucun appel à un service tiers.

- **Big Shoulders Display 900, capitales** (`--f-peint`) : lettres peintes. Utilisée pour « À LOUER », les titres de
  logement, les prix, les bandes et les tampons.
- **Marhey** (`--f-arabe`) : le « للكراء » du panneau et « سكن » de l'enseigne.
- **Figtree** (`--f-texte`) : tout le texte courant, 1 rem / 1,5.
- Chiffres en `tabular-nums`, espaces fines insécables avant « : ? ! » et dans les milliers (« 3 300 DH »).

## Composants

- **Panneau** (`Panneau.astro`) :
  - une planche blanche, cadre de 4 px, deux clous peints, légèrement penchée dans la grille (`--penche`) ;
  - ordre : « À LOUER » + arabe, titre, ville · quartier, gabarit, prix peint, tarifs semaine/mois, plan schématique, bouton.
- **Bande « LOUÉ »** :
  - sur le catalogue, collée sur la ligne « À LOUER » (LOUÉ remplace À LOUER), légèrement inclinée et rayée. Elle ne
    recouvre jamais le prix ; elle apparaît quand le logement est pris dans les 7 jours ;
  - dans le calendrier (`.bande-jours`), une bande par suite de nuits et par semaine, dans le tiers bas des cases :
    les numéros restent lisibles ;
  - dans l'espace propriétaire (`.bande-collee`), collée dans le flux sous le prix de la demande qu'on vient
    d'accepter. Elle arrive avec une animation de 420 ms et ne recouvre ni le tampon ni le texte.
- **Tampons de statut** : capitales peintes, cadre 2 px, rotation de -2°. En attente = pointillés gris,
  acceptée = vert, refusée/annulée = rouge foncé.
- **Calendrier** : deux mois, semaine du lundi, cases de 44 px minimum. Arrivée puis départ ; une nuit prise reste
  cliquable comme jour de départ.
- **Carte** : contour du Maroc (Natural Earth 50 m), épingles et noms de ville à 13 px réels.
- **Boutons** : hauteur 48 px, cadre 2 px. Le rouge est réservé à l'action principale (« Voir les dates »,
  « Demander ces dates », « Accepter »).

## Mouvement

Une seule animation porteuse de sens : la bande collée à l'acceptation (`coller`, échelle 1,6 → 1). Elle est
supprimée sous `prefers-reduced-motion`. Les transitions de bouton durent 160 ms avec `cubic-bezier(0.16, 1, 0.3, 1)`.

## Accessibilité

- Les jours du calendrier sont des `button` avec un libellé complet (« 21 novembre : loué »).
- Les bandes décoratives sont `aria-hidden` ; l'information est portée par les libellés.
- Le devis est annoncé (`aria-live`).
- Focus de 3 px visible partout, cibles de 44 px.
