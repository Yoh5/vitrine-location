# Sakan — location de logements, une nuit ne se loue qu'une fois

Démonstration du portfolio freelance (n°2 : application de location à deux espaces). **Tout est fictif** :
logements, personnes, téléphones ; aucune réservation réelle, aucun paiement.

Le locataire choisit ses dates sur un calendrier où les nuits prises portent une bande « LOUÉ », voit le prix
que la base demandera, et envoie sa demande. Le propriétaire accepte ou refuse, et bloque des dates.

## La page affiche, la base décide

| Ce que la base garantit | Comment |
|---|---|
| Une nuit ne se loue qu'une fois | contrainte d'exclusion PostgreSQL (`btree_gist`) sur les séjours acceptés + verrou par logement ; testé avec deux onglets qui acceptent en même temps |
| Le prix est le bon | calculé par la base au meilleur tarif mois / semaine / nuit (y compris « payer un mois pour 25 nuits ») ; la page n'envoie que des dates |
| Pas de conflit à gérer à la main | accepter une demande refuse d'office les autres demandes en attente sur ces nuits, avec le motif |
| Les dates bloquées comptent | un blocage du propriétaire ferme les demandes ; impossible de bloquer un séjour déjà accepté (testé en concurrence) |
| La vie privée | le téléphone de l'autre partie n'apparaît qu'après acceptation ; le calendrier public ne dit jamais qui |
| Chacun chez soi | un propriétaire ne voit ni ne touche les demandes d'un autre ; un locataire n'annule que les siennes |

Tests : `db/tests.sql` (9 groupes), `db/test_concurrence.sh` (2 courses), `python db/muter.py` (**10/10 défauts
injectés détectés**, dont « ni verrou ni contrainte » qui laisse passer une double réservation).

## Lancer en local

Il faut Docker et Node.

```bash
bash db/lancer_tests.sh          # base jetable + schéma + données + tous les tests
bash db/api_locale.sh            # API locale (PostgREST) sur le port 54331
docker exec -i sakan-db psql -U postgres < db/seed.sql && docker exec -i sakan-db psql -U postgres < db/demandes_demo.sql
npm install && PUBLIC_API_URL=http://localhost:54331 npm run dev
python db/jeton_local.py proprietaire   # session de test à mettre dans localStorage["sakan:session"]
```

## Mettre en ligne (projet Supabase neuf)

1. `bash db/preparer_supabase.sh`, puis coller `db/supabase_complet.sql` dans l'éditeur SQL du projet.
2. **Authentication → Sign In / Providers** : désactiver « Allow new users to sign up ».
3. **Authentication → Users → Add user** (« Auto Confirm ») : un compte propriétaire et un compte locataire
   de démonstration (leurs mots de passe seront publics).
4. Ouvrir `db/comptes_demo.sql`, y mettre les deux e-mails, le lancer.
5. Netlify : `PUBLIC_API_URL`, `PUBLIC_API_KEY` (clé anon / publishable), et
   `PUBLIC_DEMO_PROPRIETAIRE_EMAIL`, `PUBLIC_DEMO_PROPRIETAIRE_MOT_DE_PASSE`,
   `PUBLIC_DEMO_LOCATAIRE_EMAIL`, `PUBLIC_DEMO_LOCATAIRE_MOT_DE_PASSE`.

Les demandes de démonstration sont datées par rapport au jour du chargement : relancer `demandes_demo.sql`
(après avoir vidé `demandes` et `indisponibilites`) rajeunit la démo.

## Limites, dites franchement

- Pas de paiement en ligne (sur un vrai projet : CMI, YouCan Pay) ; au Maroc l'avance se règle souvent hors ligne.
- Pas de photos : un plan schématique les remplace, la démonstration ne montre aucun vrai logement.
- Comptes de démonstration partagés : ce qu'un visiteur fait, le suivant le voit.
- Français seulement.
