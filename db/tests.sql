-- Tests de Sakan. Base fraîchement semée (seed + demandes_demo) ; transaction annulée à la fin.
\set QUIET on
begin;

create function pg_temp.doit_echouer(appel text, attendu text) returns void
language plpgsql as $$
declare passe boolean := false;
begin
  begin
    execute appel;
    passe := true;
  exception when others then
    if sqlerrm <> attendu then
      raise exception 'ÉCHEC : % -> « % » au lieu de « % »', appel, sqlerrm, attendu;
    end if;
  end;
  if passe then raise exception 'ÉCHEC : % aurait dû être refusé (%)', appel, attendu; end if;
end $$;

create function pg_temp.egal(obtenu anyelement, attendu anyelement, quoi text) returns void
language plpgsql as $$
begin
  if obtenu is distinct from attendu then raise exception 'ÉCHEC : % = % au lieu de %', quoi, obtenu, attendu; end if;
end $$;

create function pg_temp.connecte(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;
create function pg_temp.j(n int) returns date language sql as $$ select (now() at time zone 'Africa/Casablanca')::date + n $$;
grant execute on function pg_temp.j(int) to anon, authenticated;

-- un second propriétaire, pour vérifier l'étanchéité entre propriétaires
insert into profils values ('11111111-0000-0000-0000-000000000002', 'Autre propriétaire', '0661000102', 'proprietaire');
insert into logements (proprietaire, slug, titre, ville, quartier, lat, lng, capacite, chambres, prix_nuit)
values ('11111111-0000-0000-0000-000000000002', 'autre', 'Logement d''un autre', 'Fès', 'Batha', 34.06, -4.98, 2, 1, 300);

\echo '1. Le visiteur voit le catalogue et le calendrier, rien de personnel'
set role anon;
do $$ begin
  perform pg_temp.egal((select count(*) from logements), 7::bigint, 'logements visibles');
  perform pg_temp.egal(jsonb_array_length(calendrier(1)), 2, 'deux périodes prises au Maârif (séjour + blocage de démo)');
  perform pg_temp.egal(calendrier(1)->0 ? 'locataire', false, 'le calendrier ne dit pas qui');
  perform pg_temp.egal((devis(1, pg_temp.j(40), pg_temp.j(45))->>'total')::int, 2750, 'devis 5 nuits');
  perform pg_temp.egal((devis(1, pg_temp.j(11), pg_temp.j(13))->>'libre')::boolean, false, 'devis sur dates prises');
  perform pg_temp.doit_echouer('select * from demandes', 'permission denied for table demandes');
  perform pg_temp.doit_echouer('select * from profils', 'permission denied for table profils');
  perform pg_temp.doit_echouer('select * from indisponibilites', 'permission denied for table indisponibilites');
  perform pg_temp.doit_echouer($q$select demander(1, current_date + 40, current_date + 45, 2)$q$, 'permission denied for function demander');
  perform pg_temp.doit_echouer($q$select calculer_prix(1, current_date, current_date + 3)$q$, 'permission denied for function calculer_prix');
  perform pg_temp.doit_echouer('update logements set prix_nuit = 1', 'permission denied for table logements');
end $$;
reset role;

\echo '2. Le prix : le meilleur tarif, calculé par la base'
do $$ begin
  -- Maârif : 550 la nuit, 3 300 la semaine, 11 000 le mois
  perform pg_temp.egal((calculer_prix(1, pg_temp.j(40), pg_temp.j(45))->>'total')::int, 2750, '5 nuits');
  perform pg_temp.egal((calculer_prix(1, pg_temp.j(40), pg_temp.j(47))->>'total')::int, 3300, '7 nuits = 1 semaine');
  perform pg_temp.egal((calculer_prix(1, pg_temp.j(40), pg_temp.j(50))->>'total')::int, 4950, '10 nuits = 1 semaine + 3 nuits');
  perform pg_temp.egal((calculer_prix(1, pg_temp.j(40), pg_temp.j(65))->>'total')::int, 11000, '25 nuits : le mois est moins cher');
  perform pg_temp.egal((calculer_prix(1, pg_temp.j(40), pg_temp.j(73))->>'total')::int, 12650, '33 nuits = 1 mois + 3 nuits');
  -- Riad : pas de tarif mois (1 200 / 7 500)
  perform pg_temp.egal((calculer_prix(3, pg_temp.j(40), pg_temp.j(70))->>'total')::int, 32400, '30 nuits sans tarif mois');
  perform pg_temp.egal((calculer_prix(3, pg_temp.j(40), pg_temp.j(46))->>'total')::int, 7200, '6 nuits : 6 x 1 200 < 1 semaine');
end $$;

\echo '3. Le locataire demande ; la base refuse ce qui ne va pas'
set role authenticated;
select pg_temp.connecte('22222222-0000-0000-0000-000000000001') \g /dev/null
do $$
declare d jsonb;
begin
  perform pg_temp.egal(moi()->>'role', 'locataire', 'rôle');
  d := demander(2, pg_temp.j(60), pg_temp.j(67), 1, 'Stage de deux semaines');
  perform pg_temp.egal(d->>'statut', 'en_attente', 'demande envoyée');
  perform pg_temp.egal((d->>'prix_total')::int, 2100, 'prix calculé par la base (1 semaine)');
  perform pg_temp.egal(d->'autre'->'telephone', 'null'::jsonb, 'téléphone du propriétaire caché avant acceptation');
  perform pg_temp.egal(d->'autre'->>'nom', 'Hajja Fatima Bennani', 'nom du propriétaire visible');
  perform pg_temp.doit_echouer($q$select demander(2, pg_temp.j(62), pg_temp.j(69), 1)$q$, 'demande_deja_envoyee');
  perform pg_temp.doit_echouer($q$select demander(1, pg_temp.j(12), pg_temp.j(14), 2)$q$, 'dates_indisponibles');   -- séjour accepté
  perform pg_temp.doit_echouer($q$select demander(5, pg_temp.j(4), pg_temp.j(6), 2)$q$, 'dates_indisponibles');     -- blocage
  perform pg_temp.doit_echouer($q$select demander(1, pg_temp.j(-3), pg_temp.j(2), 2)$q$, 'date_passee');
  perform pg_temp.doit_echouer($q$select demander(1, pg_temp.j(50), pg_temp.j(50), 2)$q$, 'dates_invalides');
  perform pg_temp.doit_echouer($q$select demander(1, pg_temp.j(50), pg_temp.j(55), 5)$q$, 'trop_de_personnes');
  perform pg_temp.doit_echouer($q$select demander(6, pg_temp.j(80), pg_temp.j(83), 2)$q$, 'sejour_trop_court');
  perform pg_temp.doit_echouer($q$select demander(1, pg_temp.j(50), pg_temp.j(500), 2)$q$, 'sejour_trop_long');
  perform pg_temp.doit_echouer($q$select demander(1, pg_temp.j(50), pg_temp.j(52), 2, repeat('x', 501))$q$, 'message_trop_long');
  perform pg_temp.doit_echouer($q$select demandes_recues()$q$, 'reserve_aux_proprietaires');
  perform pg_temp.doit_echouer($q$select accepter(1)$q$, 'demande_introuvable');
  perform pg_temp.egal(jsonb_array_length(mes_demandes()), 3, 'il ne voit que SES demandes (2 de démo + la nouvelle)');
end $$;

\echo '4. Le propriétaire accepte : l''autre demande en conflit est refusée d''office'
select pg_temp.connecte('11111111-0000-0000-0000-000000000001') \g /dev/null
do $$
declare
  salma int := (select (x->>'id')::int from jsonb_array_elements(demandes_recues('en_attente')) x where x->'autre'->>'nom' = 'Salma Idrissi');
  mehdi int := (select (x->>'id')::int from jsonb_array_elements(demandes_recues('en_attente')) x where x->'autre'->>'nom' = 'Mehdi Tazi');
  r jsonb;
begin
  perform pg_temp.doit_echouer($q$select demander(1, pg_temp.j(40), pg_temp.j(45), 2)$q$, 'reserve_aux_locataires');
  perform pg_temp.egal((select x->'autre'->'telephone' from jsonb_array_elements(demandes_recues()) x where (x->>'id')::int = salma),
                       'null'::jsonb, 'téléphone du locataire caché avant acceptation');
  r := accepter(salma);
  perform pg_temp.egal(r->>'statut', 'acceptee', 'acceptée');
  perform pg_temp.egal((r->>'refusees_d_office')::int, 1, 'la demande concurrente est refusée d''office');
  perform pg_temp.egal(r->'autre'->>'telephone', '0662000203', 'téléphone du locataire révélé après acceptation');
  perform pg_temp.egal((select x->>'motif' from jsonb_array_elements(demandes_recues()) x where (x->>'id')::int = mehdi),
                       'dates attribuées à une autre demande', 'motif du refus d''office');
  perform pg_temp.doit_echouer(format('select accepter(%s)', salma), 'deja_close');
  perform pg_temp.doit_echouer(format('select accepter(%s)', mehdi), 'deja_close');
  perform pg_temp.doit_echouer(format('select refuser(%s, %L)', (select (x->>'id')::int from jsonb_array_elements(demandes_recues('en_attente')) x limit 1), 'x'), 'motif_requis');
end $$;

\echo '5. Un propriétaire ne touche pas aux demandes d''un autre'
select pg_temp.connecte('11111111-0000-0000-0000-000000000002') \g /dev/null
do $$ begin
  perform pg_temp.egal(jsonb_array_length(demandes_recues()), 0, 'aucune demande de l''autre propriétaire');
  perform pg_temp.doit_echouer('select accepter(1)', 'demande_introuvable');
  perform pg_temp.doit_echouer($q$select refuser(1, 'non merci')$q$, 'demande_introuvable');
  perform pg_temp.doit_echouer($q$select bloquer(1, pg_temp.j(100), pg_temp.j(102))$q$, 'logement_introuvable');
end $$;

\echo '6. Blocages : impossible sur un séjour accepté ; un blocage ferme les demandes'
select pg_temp.connecte('11111111-0000-0000-0000-000000000001') \g /dev/null
do $$
declare b jsonb;
begin
  perform pg_temp.doit_echouer($q$select bloquer(1, pg_temp.j(12), pg_temp.j(20), 'famille')$q$, 'dates_indisponibles');
  b := bloquer(1, pg_temp.j(100), pg_temp.j(103), 'famille');
  perform pg_temp.egal(jsonb_array_length(calendrier(1)), 3, 'blocage visible au calendrier');
  perform pg_temp.connecte('22222222-0000-0000-0000-000000000001');
  perform pg_temp.doit_echouer($q$select demander(1, pg_temp.j(101), pg_temp.j(105), 2)$q$, 'dates_indisponibles');
  perform pg_temp.connecte('11111111-0000-0000-0000-000000000001');
  perform debloquer((b->>'id')::int);
  perform pg_temp.connecte('22222222-0000-0000-0000-000000000001');
  perform pg_temp.egal(demander(1, pg_temp.j(101), pg_temp.j(105), 2)->>'statut', 'en_attente', 'demande possible après déblocage');
end $$;

\echo '7. Le locataire annule ; il ne peut pas annuler la demande d''un autre'
select pg_temp.connecte('22222222-0000-0000-0000-000000000001') \g /dev/null
do $$
declare mienne int := (select (x->>'id')::int from jsonb_array_elements(mes_demandes()) x where (x->'logement'->>'id')::int = 2 and x->>'statut' = 'en_attente');
begin
  perform pg_temp.egal(annuler(mienne)->>'statut', 'annulee', 'annulée');
  perform pg_temp.doit_echouer(format('select annuler(%s)', mienne), 'deja_close');
  perform pg_temp.doit_echouer('select annuler(1)', 'demande_introuvable');   -- celle de Youssef
end $$;

\echo '8. Compte connecté sans profil : refusé'
select pg_temp.connecte('99999999-0000-0000-0000-000000000009') \g /dev/null
do $$ begin
  perform pg_temp.doit_echouer('select moi()', 'acces_refuse');
  perform pg_temp.doit_echouer('select mes_demandes()', 'acces_refuse');
  perform pg_temp.doit_echouer('select demandes_recues()', 'acces_refuse');
end $$;
reset role;

\echo '9. Filet de sécurité : la contrainte refuse deux séjours acceptés qui se chevauchent, même en direct'
do $$ begin
  perform pg_temp.doit_echouer(
    format($q$insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, statut)
              values (1, '22222222-0000-0000-0000-000000000004', %L, %L, 1, 1, '{}', 'acceptee')$q$, pg_temp.j(12), pg_temp.j(13)),
    'conflicting key value violates exclusion constraint "pas_de_double_reservation"');
end $$;

\echo '10. Remise à zéro de la démo : réservée au serveur, idempotente, suit le compte relié'
set role authenticated;
do $$ begin perform pg_temp.doit_echouer('select reinitialiser_demo()', 'permission denied for function reinitialiser_demo'); end $$;
reset role;
set role anon;
do $$ begin perform pg_temp.doit_echouer('select reinitialiser_demo()', 'permission denied for function reinitialiser_demo'); end $$;
reset role;
do $$ begin
  -- les tests précédents ont sali la base (acceptations, blocages, annulations) : la remise à zéro repart du jeu de démo
  perform pg_temp.egal(reinitialiser_demo(), 7, 'sept demandes reposées');
  perform pg_temp.egal((select count(*)::int from indisponibilites), 2, 'deux blocages reposés');
  perform pg_temp.egal(jsonb_array_length(calendrier(1)), 2, 'Maârif : séjour + blocage');
  perform pg_temp.egal(reinitialiser_demo(), 7, 'deuxième passage identique');
  -- sur Supabase le locataire de démo est relié à un vrai compte : ses demandes suivent ce compte
  update profils set user_id = '33333333-0000-0000-0000-000000000003' where nom = 'Visiteur locataire';
  perform reinitialiser_demo();
  perform pg_temp.egal((select count(*)::int from demandes where locataire = '33333333-0000-0000-0000-000000000003'), 2, 'demandes du compte relié');
end $$;

\echo 'Tous les tests passent.'
rollback;
