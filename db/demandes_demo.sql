-- Demandes de démonstration, datées par rapport à AUJOURD'HUI (pour que la démo ne vieillisse pas).
-- Insérées directement (pas par demander()) car les locataires fictifs n'ont pas de compte.
do $$
declare
  j date := (now() at time zone 'Africa/Casablanca')::date;
  y uuid := '22222222-0000-0000-0000-000000000002';
  s uuid := '22222222-0000-0000-0000-000000000003';
  m uuid := '22222222-0000-0000-0000-000000000004';
begin
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
  -- le propriétaire bloque Chefchaouen pour travaux
  insert into indisponibilites (logement_id, debut, fin, raison) values (5, j + 3, j + 9, 'peinture');
end $$;
