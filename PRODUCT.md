# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

delegated (20/11/2026) : **Astro** (pages publiques des logements construites à l'avance, une page par logement) + îlots TypeScript sans framework pour les espaces connectés ; **Supabase** (PostgreSQL + Auth) ; hébergement Netlify. Même socle que Dar Hdiya (n°1 et n°6) : sessions et appels à la base repris de l'espace du gérant.

## Users

Premier public, confirmé par les offres reçues : **un propriétaire ou une agence au Maroc** qui loue quelques appartements (courte et moyenne durée) et qui a demandé sur freelancer.ma une application à deux espaces, propriétaire et locataire. Second public, mis en scène : le locataire qui cherche et demande des dates.

## Product Purpose

Démonstration d'une application de location complète : catalogue public avec carte et calendrier des disponibilités, demande de séjour par le locataire, acceptation ou refus par le propriétaire, dates bloquées, prix au jour / à la semaine / au mois. Succès : un propriétaire essaie les deux comptes de démonstration et comprend en 3 minutes qu'il ne pourra jamais louer deux fois les mêmes nuits.

## Positioning

**La page affiche, la base décide.** Pas de double réservation, même avec deux onglets ou deux personnes en même temps (contrainte d'exclusion PostgreSQL, test de concurrence) ; prix calculé par la base au meilleur tarif ; accepter une demande refuse d'office les demandes en conflit ; coordonnées de l'autre partie révélées seulement après acceptation ; calendrier public sans identité. Tout est testé (9 groupes, 2 tests de concurrence, mutations).

## Operating Context

Le locataire cherche sur téléphone ; le propriétaire gère surtout sur téléphone aussi (répondre vite à une demande). Maroc : confirmation par téléphone ou WhatsApp après acceptation, paiement hors application (avance, espèces, virement) — la démo ne prend aucun paiement.

## Capabilities and Constraints

- 6 logements fictifs (Casablanca, Rabat, Marrakech, Tanger, Chefchaouen, Agadir) appartenant à un propriétaire de démonstration ; locataires fictifs avec demandes datées par rapport au jour même.
- Deux comptes de démonstration à identifiants publics (propriétaire, locataire) ; inscriptions fermées.
- Pas de paiement en ligne (à brancher sur un vrai projet : CMI, YouCan Pay).
- Français seulement pour la démo.

## Brand Commitments

Nom fictif **Sakan** (« logement » en arabe). Design propre à cette vitrine : ne reprendre ni Dar Zellige, Warda, Mouja, Silicium, Dar Hdiya ni Pointage.

## Evidence on Hand

- Base et tests : `db/` (schéma, données, tests, concurrence, mutations).
- Aucun avis, aucune note, aucune réservation réelle, aucune photo de vrai logement : n'en afficher ni n'en inventer.

## Product Principles

1. Une nuit ne se loue qu'une fois : la garantie est dans la base, pas dans la page.
2. Le prix affiché est celui que la base demandera.
3. La vie privée d'abord : pas de téléphone avant l'accord.
4. Le propriétaire décide ; l'outil lui épargne les conflits.

## Accessibility & Inclusion

WCAG AA : contrastes 4,5:1, clavier complet (choix des dates compris), disponibilité lisible sans la couleur.
