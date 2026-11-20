-- Sakan — location de logements, démonstration (fictive).
-- Principe : la page affiche, la base décide.
--   * Deux séjours acceptés ne peuvent pas se chevaucher : contrainte d'exclusion, même sous la concurrence.
--   * Le prix est calculé ici (mois, semaine, nuit : le meilleur tarif), jamais envoyé par la page.
--   * Accepter une demande refuse d'office les demandes en attente sur les mêmes dates.
--   * Les coordonnées de l'autre partie ne sont visibles qu'une fois la demande acceptée.
--   * Le calendrier public dit ce qui est pris, jamais par qui.
-- Tout passe par des fonctions security definer ; les tables ne sont lisibles que par ces fonctions
-- (sauf le catalogue des logements, lisible par tous).

create extension if not exists btree_gist;

-- ---------------------------------------------------------------- tables

create table if not exists profils (
  user_id   uuid primary key,             -- = auth.users.id pour un compte qui se connecte ; les profils fictifs de la démo n'en ont pas
  nom       text not null check (length(btrim(nom)) between 2 and 80),
  telephone text not null check (telephone ~ '^0[5-7]\d{8}$'),
  role      text not null check (role in ('proprietaire', 'locataire'))
);

create table if not exists logements (
  id            serial primary key,
  proprietaire  uuid not null references profils(user_id) on update cascade,
  slug          text not null unique,
  titre         text not null,
  ville         text not null,
  quartier      text not null,
  lat           numeric(8,5) not null,
  lng           numeric(8,5) not null,
  description   text not null default '',
  capacite      integer not null check (capacite between 1 and 20),
  chambres      integer not null check (chambres between 0 and 10),
  prix_nuit     integer not null check (prix_nuit > 0),               -- DH
  prix_semaine  integer check (prix_semaine > 0),                     -- 7 nuits ; null = pas de tarif semaine
  prix_mois     integer check (prix_mois > 0),                        -- 30 nuits ; null = pas de tarif mois
  sejour_min    integer not null default 1 check (sejour_min between 1 and 30),
  actif         boolean not null default true,
  -- un tarif long n'a de sens que s'il est moins cher que la somme des nuits
  check (prix_semaine is null or prix_semaine < 7 * prix_nuit),
  check (prix_mois is null or prix_mois < 30 * prix_nuit)
);

create table if not exists demandes (
  id           serial primary key,
  logement_id  integer not null references logements(id),
  locataire    uuid not null references profils(user_id) on update cascade,
  debut        date not null,                 -- nuit d'arrivée
  fin          date not null,                 -- jour de départ (exclu)
  personnes    integer not null check (personnes between 1 and 20),
  prix_total   integer not null,
  detail_prix  jsonb not null,
  message      text not null default '' check (length(message) <= 500),
  statut       text not null default 'en_attente'
               check (statut in ('en_attente', 'acceptee', 'refusee', 'annulee')),
  motif        text,
  cree_le      timestamptz not null default now(),
  decide_le    timestamptz,
  check (fin > debut),
  -- LA garantie : deux séjours acceptés ne se chevauchent jamais sur un même logement
  constraint pas_de_double_reservation exclude using gist
    (logement_id with =, daterange(debut, fin) with &&) where (statut = 'acceptee')
);

create table if not exists indisponibilites (
  id           serial primary key,
  logement_id  integer not null references logements(id),
  debut        date not null,
  fin          date not null,
  raison       text not null default '' check (length(raison) <= 120),
  check (fin > debut),
  constraint pas_de_blocage_double exclude using gist (logement_id with =, daterange(debut, fin) with &&)
);

-- ---------------------------------------------------------------- accès

alter table profils          enable row level security;
alter table logements        enable row level security;
alter table demandes         enable row level security;
alter table indisponibilites enable row level security;
revoke all on profils, logements, demandes, indisponibilites from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
-- le catalogue est public (logements actifs seulement)
grant select on logements to anon, authenticated;
drop policy if exists catalogue on logements;
create policy catalogue on logements for select to anon, authenticated using (actif);

-- ---------------------------------------------------------------- outils internes

create or replace function moi_profil(out o_id uuid, out o_role text, out o_nom text)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  select p.user_id, p.role, p.nom into o_id, o_role, o_nom from profils p where p.user_id = auth.uid();
  if o_id is null then raise exception 'acces_refuse'; end if;
end $$;

-- Meilleur prix pour n nuits : mois (30), semaines (7) et nuits combinés, y compris « payer une semaine
-- pour 6 nuits » quand c'est moins cher. Retourne le total et le détail lisible.
create or replace function calculer_prix(p_logement integer, p_debut date, p_fin date) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  l logements;
  n integer := p_fin - p_debut;
  meilleur integer;
  d jsonb;
  m integer; w integer; reste integer; nuits integer; total integer;
begin
  select * into l from logements where id = p_logement;
  if not found then raise exception 'logement_introuvable'; end if;
  for m in 0 .. case when l.prix_mois is null then 0 else (n + 29) / 30 end loop
    reste := greatest(n - 30 * m, 0);
    for w in 0 .. case when l.prix_semaine is null then 0 else (reste + 6) / 7 end loop
      nuits := greatest(reste - 7 * w, 0);
      total := m * coalesce(l.prix_mois, 0) + w * coalesce(l.prix_semaine, 0) + nuits * l.prix_nuit;
      if meilleur is null or total < meilleur then
        meilleur := total;
        d := jsonb_build_object('nuits', n, 'mois', m, 'semaines', w, 'nuits_seules', nuits,
                                'prix_mois', l.prix_mois, 'prix_semaine', l.prix_semaine, 'prix_nuit', l.prix_nuit,
                                'sans_remise', n * l.prix_nuit);
      end if;
    end loop;
  end loop;
  return d || jsonb_build_object('total', meilleur);
end $$;

-- Les dates sont-elles libres (aucun séjour accepté, aucun blocage) ? Appelée après verrouillage du logement.
create or replace function dates_libres(p_logement integer, p_debut date, p_fin date, p_sauf integer default null) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select not exists (select 1 from demandes d where d.logement_id = p_logement and d.statut = 'acceptee'
                       and d.id is distinct from p_sauf and daterange(d.debut, d.fin) && daterange(p_debut, p_fin))
     and not exists (select 1 from indisponibilites i where i.logement_id = p_logement
                       and daterange(i.debut, i.fin) && daterange(p_debut, p_fin))
$$;

-- Une demande vue par l'un ou l'autre : coordonnées de l'autre partie seulement si acceptée.
create or replace function demande_vue(d demandes, p_pour text) returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'id', d.id, 'statut', d.statut, 'debut', d.debut, 'fin', d.fin, 'nuits', d.fin - d.debut,
    'personnes', d.personnes, 'prix_total', d.prix_total, 'detail_prix', d.detail_prix,
    'message', d.message, 'motif', d.motif, 'cree_le', d.cree_le, 'decide_le', d.decide_le,
    'logement', jsonb_build_object('id', l.id, 'slug', l.slug, 'titre', l.titre, 'ville', l.ville, 'quartier', l.quartier),
    'autre', case
      when p_pour = 'proprietaire' then jsonb_build_object('nom', loc.nom,
             'telephone', case when d.statut = 'acceptee' then loc.telephone end)
      else jsonb_build_object('nom', pro.nom,
             'telephone', case when d.statut = 'acceptee' then pro.telephone end) end)
  from logements l
  join profils loc on loc.user_id = d.locataire
  join profils pro on pro.user_id = l.proprietaire
  where l.id = d.logement_id
$$;

-- ---------------------------------------------------------------- portes publiques

-- Calendrier : périodes prises (séjours acceptés et blocages), sans dire par qui ni pourquoi.
create or replace function calendrier(p_logement integer, p_depuis date default current_date) returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('debut', debut, 'fin', fin) order by debut), '[]'::jsonb)
  from (
    select debut, fin from demandes where logement_id = p_logement and statut = 'acceptee' and fin > p_depuis
    union all
    select debut, fin from indisponibilites where logement_id = p_logement and fin > p_depuis
  ) x
$$;

-- Devis : le prix que la base demandera, sans rien réserver.
create or replace function devis(p_logement integer, p_debut date, p_fin date) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare l logements;
begin
  select * into l from logements where id = p_logement and actif;
  if not found then raise exception 'logement_introuvable'; end if;
  if p_debut is null or p_fin is null or p_fin <= p_debut then raise exception 'dates_invalides'; end if;
  if p_fin - p_debut > 365 then raise exception 'sejour_trop_long'; end if;
  if p_fin - p_debut < l.sejour_min then raise exception 'sejour_trop_court'; end if;
  return calculer_prix(p_logement, p_debut, p_fin) || jsonb_build_object('libre', dates_libres(p_logement, p_debut, p_fin));
end $$;

-- ---------------------------------------------------------------- locataire

create or replace function demander(p_logement integer, p_debut date, p_fin date, p_personnes integer, p_message text default '')
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  moi record;
  l logements;
  prix jsonb;
  v_id integer;
begin
  select * into moi from moi_profil();
  if moi.o_role <> 'locataire' then raise exception 'reserve_aux_locataires'; end if;
  select * into l from logements where id = p_logement and actif for update;   -- sérialise par logement
  if not found then raise exception 'logement_introuvable'; end if;
  if p_debut is null or p_fin is null or p_fin <= p_debut then raise exception 'dates_invalides'; end if;
  if p_debut < (now() at time zone 'Africa/Casablanca')::date then raise exception 'date_passee'; end if;
  if p_fin - p_debut > 365 then raise exception 'sejour_trop_long'; end if;
  if p_fin - p_debut < l.sejour_min then raise exception 'sejour_trop_court'; end if;
  if p_personnes is null or p_personnes < 1 or p_personnes > l.capacite then raise exception 'trop_de_personnes'; end if;
  if length(coalesce(p_message, '')) > 500 then raise exception 'message_trop_long'; end if;
  if not dates_libres(p_logement, p_debut, p_fin) then raise exception 'dates_indisponibles'; end if;
  if exists (select 1 from demandes where logement_id = p_logement and locataire = moi.o_id and statut = 'en_attente'
             and daterange(debut, fin) && daterange(p_debut, p_fin)) then raise exception 'demande_deja_envoyee'; end if;
  prix := calculer_prix(p_logement, p_debut, p_fin);
  insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix, message)
  values (p_logement, moi.o_id, p_debut, p_fin, p_personnes, (prix->>'total')::integer, prix, btrim(coalesce(p_message, '')))
  returning id into v_id;
  return demande_vue((select d from demandes d where d.id = v_id), 'locataire');
end $$;

create or replace function mes_demandes() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare moi record;
begin
  select * into moi from moi_profil();
  return coalesce((select jsonb_agg(demande_vue(d, 'locataire') order by d.cree_le desc)
                   from demandes d where d.locataire = moi.o_id), '[]'::jsonb);
end $$;

-- Annuler : une demande en attente, ou un séjour accepté qui n'a pas commencé.
create or replace function annuler(p_demande integer) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare moi record; d demandes;
begin
  select * into moi from moi_profil();
  select * into d from demandes where id = p_demande and locataire = moi.o_id for update;
  if not found then raise exception 'demande_introuvable'; end if;
  if d.statut not in ('en_attente', 'acceptee') then raise exception 'deja_close'; end if;
  if d.statut = 'acceptee' and d.debut <= (now() at time zone 'Africa/Casablanca')::date then raise exception 'sejour_commence'; end if;
  update demandes set statut = 'annulee', decide_le = now(), motif = 'annulée par le locataire' where id = d.id;
  return demande_vue((select x from demandes x where x.id = d.id), 'locataire');
end $$;

-- ---------------------------------------------------------------- propriétaire

create or replace function demandes_recues(p_statut text default null) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare moi record;
begin
  select * into moi from moi_profil();
  if moi.o_role <> 'proprietaire' then raise exception 'reserve_aux_proprietaires'; end if;
  return coalesce((select jsonb_agg(demande_vue(d, 'proprietaire') order by d.debut, d.cree_le)
                   from demandes d join logements l on l.id = d.logement_id
                   where l.proprietaire = moi.o_id and (p_statut is null or d.statut = p_statut)), '[]'::jsonb);
end $$;

create or replace function accepter(p_demande integer) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare moi record; d demandes; n integer;
begin
  select * into moi from moi_profil();
  select dm.* into d from demandes dm join logements l on l.id = dm.logement_id
  where dm.id = p_demande and l.proprietaire = moi.o_id;
  if not found then raise exception 'demande_introuvable'; end if;
  perform 1 from logements where id = d.logement_id for update;                -- un seul arbitrage à la fois
  select * into d from demandes where id = p_demande for update;
  if d.statut <> 'en_attente' then raise exception 'deja_close'; end if;
  if not dates_libres(d.logement_id, d.debut, d.fin) then raise exception 'dates_indisponibles'; end if;
  update demandes set statut = 'acceptee', decide_le = now() where id = d.id;
  -- les autres demandes en attente sur ces dates sont refusées d'office, avec le motif
  update demandes set statut = 'refusee', decide_le = now(), motif = 'dates attribuées à une autre demande'
  where logement_id = d.logement_id and statut = 'en_attente' and id <> d.id
    and daterange(debut, fin) && daterange(d.debut, d.fin);
  get diagnostics n = row_count;
  return demande_vue((select x from demandes x where x.id = d.id), 'proprietaire') || jsonb_build_object('refusees_d_office', n);
end $$;

create or replace function refuser(p_demande integer, p_motif text) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare moi record; d demandes; v_motif text := btrim(coalesce(p_motif, ''));
begin
  select * into moi from moi_profil();
  select dm.* into d from demandes dm join logements l on l.id = dm.logement_id
  where dm.id = p_demande and l.proprietaire = moi.o_id for update of dm;
  if not found then raise exception 'demande_introuvable'; end if;
  if d.statut <> 'en_attente' then raise exception 'deja_close'; end if;
  if length(v_motif) < 3 then raise exception 'motif_requis'; end if;
  if length(v_motif) > 200 then raise exception 'motif_trop_long'; end if;
  update demandes set statut = 'refusee', decide_le = now(), motif = v_motif where id = d.id;
  return demande_vue((select x from demandes x where x.id = d.id), 'proprietaire');
end $$;

create or replace function bloquer(p_logement integer, p_debut date, p_fin date, p_raison text default '') returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare moi record; v_id integer;
begin
  select * into moi from moi_profil();
  perform 1 from logements where id = p_logement and proprietaire = moi.o_id for update;
  if not found then raise exception 'logement_introuvable'; end if;
  if p_debut is null or p_fin is null or p_fin <= p_debut then raise exception 'dates_invalides'; end if;
  if not dates_libres(p_logement, p_debut, p_fin) then raise exception 'dates_indisponibles'; end if;
  insert into indisponibilites (logement_id, debut, fin, raison) values (p_logement, p_debut, p_fin, btrim(coalesce(p_raison, '')))
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'debut', p_debut, 'fin', p_fin);
end $$;

create or replace function debloquer(p_blocage integer) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare moi record;
begin
  select * into moi from moi_profil();
  delete from indisponibilites i using logements l
  where i.id = p_blocage and l.id = i.logement_id and l.proprietaire = moi.o_id;
  if not found then raise exception 'blocage_introuvable'; end if;
end $$;

create or replace function mes_logements() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare moi record;
begin
  select * into moi from moi_profil();
  if moi.o_role <> 'proprietaire' then raise exception 'reserve_aux_proprietaires'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', l.id, 'slug', l.slug, 'titre', l.titre, 'ville', l.ville, 'prix_nuit', l.prix_nuit,
      'en_attente', (select count(*) from demandes d where d.logement_id = l.id and d.statut = 'en_attente'),
      'blocages', (select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'debut', i.debut, 'fin', i.fin, 'raison', i.raison) order by i.debut), '[]'::jsonb)
                   from indisponibilites i where i.logement_id = l.id and i.fin > current_date)) order by l.id)
    from logements l where l.proprietaire = moi.o_id), '[]'::jsonb);
end $$;

create or replace function moi() returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object('role', o_role, 'nom', o_nom) from moi_profil()
$$;

-- ---------------------------------------------------------------- droits

do $$
declare f text;
begin
  foreach f in array array['moi_profil()', 'calculer_prix(integer, date, date)', 'dates_libres(integer, date, date, integer)',
                           'demande_vue(demandes, text)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['calendrier(integer, date)', 'devis(integer, date, date)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to anon, authenticated', f);
  end loop;
  foreach f in array array['demander(integer, date, date, integer, text)', 'mes_demandes()', 'annuler(integer)',
                           'demandes_recues(text)', 'accepter(integer)', 'refuser(integer, text)',
                           'bloquer(integer, date, date, text)', 'debloquer(integer)', 'mes_logements()', 'moi()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
