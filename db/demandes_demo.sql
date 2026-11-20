-- Demandes de démonstration, datées par rapport à AUJOURD'HUI, et leur REMISE À ZÉRO.
-- reinitialiser_demo() efface demandes et blocages puis repose le jeu de démonstration ; pg_cron la relance
-- chaque nuit (si l'extension est activée) : la démo ne vieillit pas et ce que les visiteurs ont fait disparaît.
-- Insérées directement (pas par demander()) car les locataires fictifs n'ont pas de compte.
-- Sur Supabase, le locataire de démo a été relié à un vrai compte (comptes_demo.sql) : on le retrouve par son profil.
create or replace function reinitialiser_demo() returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  j date := (now() at time zone 'Africa/Casablanca')::date;
  v uuid := (select user_id from profils where role = 'locataire' and nom = 'Visiteur locataire');
  y uuid := '22222222-0000-0000-0000-000000000002';
  s uuid := '22222222-0000-0000-0000-000000000003';
  m uuid := '22222222-0000-0000-0000-000000000004';
  n integer;
begin
  if v is null then raise exception 'profil du locataire de démonstration introuvable'; end if;
  delete from demandes;
  delete from indisponibilites;
  -- séjour accepté au Maârif dans 10 jours
  insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, message, statut, decide_le)
  select 1, y, j + 10, j + 15, 2, (calculer_prix(1, j + 10, j + 15)->>'total')::int, calculer_prix(1, j + 10, j + 15),
         'Mission de travail, arrivée en fin d''après-midi.', 'acceptee', now();
  -- deux demandes EN CONCURRENCE sur le riad : accepter l'une refusera l'autre
  insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, message)
  select 3, s, j + 20, j + 27, 5, (calculer_prix(3, j + 20, j + 27)->>'total')::int, calculer_prix(3, j + 20, j + 27),
         'Vacances en famille, deux enfants.';
  insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, message)
  select 3, m, j + 24, j + 28, 4, (calculer_prix(3, j + 24, j + 28)->>'total')::int, calculer_prix(3, j + 24, j + 28),
         'Week-end prolongé entre amis.';
  -- une demande d'un mois à Agadir (tarif mois)
  insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, message)
  select 6, y, j + 30, j + 60, 2, (calculer_prix(6, j + 30, j + 60)->>'total')::int, calculer_prix(6, j + 30, j + 60),
         'Retraités, nous cherchons le soleil pour janvier.';
  -- une demande refusée hier
  insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, message, statut, motif, decide_le)
  select 4, m, j + 5, j + 8, 6, (calculer_prix(4, j + 5, j + 8)->>'total')::int, calculer_prix(4, j + 5, j + 8),
         '', 'refusee', 'six personnes pour cinq couchages', now() - interval '1 day';
  -- le locataire de DÉMO a déjà un séjour accepté (téléphone du propriétaire visible) et une demande en attente
  insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, message, statut, decide_le)
  select 2, v, j + 40, j + 54, 1, (calculer_prix(2, j + 40, j + 54)->>'total')::int,
         calculer_prix(2, j + 40, j + 54), 'Stage de deux semaines à Rabat.', 'acceptee', now() - interval '2 days';
  insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, message)
  select 4, v, j + 70, j + 77, 3, (calculer_prix(4, j + 70, j + 77)->>'total')::int,
         calculer_prix(4, j + 70, j + 77), 'Une semaine au bord de la mer en famille.';
  -- le Maârif (premier panneau) est pris cette semaine : la bande « LOUÉ » se voit dès le premier écran, même sur téléphone
  insert into indisponibilites (logement_id, debut, fin, raison) values (1, j + 1, j + 4, 'famille');
  -- le propriétaire bloque Chefchaouen pour travaux
  insert into indisponibilites (logement_id, debut, fin, raison) values (5, j + 3, j + 9, 'peinture');
  select count(*) into n from demandes;
  return n;
end $$;
revoke all on function reinitialiser_demo() from public, anon, authenticated;

select reinitialiser_demo();

-- Remise à zéro chaque nuit à 3 h (heure de Casablanca ≈ UTC), si pg_cron est activé (Supabase : Integrations > Cron).
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('sakan-remise-a-zero', '0 3 * * *', 'select public.reinitialiser_demo()');
  end if;
end $$;
