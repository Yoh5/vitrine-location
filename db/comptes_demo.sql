-- À lancer sur Supabase APRÈS avoir créé les deux comptes (Authentication > Users > Add user, « Auto Confirm »).
-- Relie les profils de démonstration aux vrais comptes ; logements et demandes suivent (on update cascade).
-- Remplacer les deux e-mails avant de lancer.
update profils set user_id = (select id from auth.users where email = 'EMAIL-DU-PROPRIETAIRE-DEMO')
where user_id = '11111111-0000-0000-0000-000000000001';
update profils set user_id = (select id from auth.users where email = 'EMAIL-DU-LOCATAIRE-DEMO')
where user_id = '22222222-0000-0000-0000-000000000001';
select nom, role, user_id from profils where role in ('proprietaire', 'locataire') order by role, nom;
