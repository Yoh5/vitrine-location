-- Données de démonstration — tout est FICTIF (personnes, téléphones, logements, prix).
-- Les deux comptes de démonstration (propriétaire et locataire) sont reliés à leurs profils dans comptes_demo.sql.
truncate demandes, indisponibilites, logements, profils restart identity cascade;

insert into profils (user_id, nom, telephone, role) values
  ('11111111-0000-0000-0000-000000000001', 'Hajja Fatima Bennani', '0661000101', 'proprietaire'),  -- propriétaire de démo
  ('22222222-0000-0000-0000-000000000001', 'Visiteur locataire',   '0662000201', 'locataire'),     -- locataire de démo
  ('22222222-0000-0000-0000-000000000002', 'Youssef Amrani',       '0662000202', 'locataire'),
  ('22222222-0000-0000-0000-000000000003', 'Salma Idrissi',        '0662000203', 'locataire'),
  ('22222222-0000-0000-0000-000000000004', 'Mehdi Tazi',           '0662000204', 'locataire');

insert into logements (proprietaire, slug, titre, ville, quartier, lat, lng, description, capacite, chambres,
                       prix_nuit, prix_semaine, prix_mois, sejour_min) values
('11111111-0000-0000-0000-000000000001', 'appartement-maarif', 'Appartement lumineux au Maârif', 'Casablanca', 'Maârif',
 33.58010, -7.63330, 'Deux chambres au 4e étage avec ascenseur, à cinq minutes du boulevard Zerktouni. Cuisine équipée, wifi, climatisation.', 4, 2, 550, 3300, 11000, 2),
('11111111-0000-0000-0000-000000000001', 'studio-agdal', 'Studio meublé à Agdal', 'Rabat', 'Agdal',
 33.99550, -6.85140, 'Studio calme près de la gare Rabat-Agdal et des facultés. Idéal pour un stage ou une mission.', 2, 0, 350, 2100, 6500, 3),
('11111111-0000-0000-0000-000000000001', 'riad-medina-marrakech', 'Riad familial dans la médina', 'Marrakech', 'Médina, Bab Doukkala',
 31.63360, -7.99760, 'Trois chambres autour d''un patio, terrasse avec vue sur l''Atlas. Petit-déjeuner possible sur demande.', 6, 3, 1200, 7500, null, 2),
('11111111-0000-0000-0000-000000000001', 'vue-mer-malabata', 'Appartement vue mer à Malabata', 'Tanger', 'Malabata',
 35.77580, -5.77840, 'Balcon face au détroit, plage à 200 m. Parking dans la résidence.', 5, 2, 700, 4200, 13500, 3),
('11111111-0000-0000-0000-000000000001', 'maison-bleue-chefchaouen', 'Maison bleue au cœur de Chefchaouen', 'Chefchaouen', 'Médina',
 35.17140, -5.26970, 'Petite maison traditionnelle sur deux niveaux, à deux pas de la place Outa el Hammam.', 3, 1, 450, 2700, null, 2),
('11111111-0000-0000-0000-000000000001', 'appartement-plage-agadir', 'Appartement près de la plage', 'Agadir', 'Founty',
 30.40140, -9.58120, 'Résidence avec piscine, plage à pied, idéal pour un mois d''hiver au soleil.', 4, 2, 500, 3000, 9000, 7);
