"""Tests par mutation de schema.sql : chaque défaut injecté doit faire échouer la suite (lancer_tests.sh).
Usage : python db/muter.py   (Docker requis ; ~30 s par mutation)"""
import subprocess
from pathlib import Path

D = Path(__file__).resolve().parent
F = D / "schema.sql"
orig = F.read_text(encoding="utf-8")
MUTATIONS = [
    ("téléphone révélé avant acceptation", "'telephone', case when d.statut = 'acceptee' then loc.telephone end", "'telephone', loc.telephone"),
    ("pas de refus d'office des demandes concurrentes", "update demandes set statut = 'refusee', decide_le = now(), motif = 'dates attribuées à une autre demande'", "update demandes set motif = motif"),
    ("prix sans « payer un mois pour 25 nuits »", "(n + 29) / 30", "n / 30"),
    ("blocages ignorés", "and not exists (select 1 from indisponibilites i where i.logement_id = p_logement", "and not exists (select 1 from indisponibilites i where false and i.logement_id = p_logement"),
    ("un propriétaire accepte les demandes d'un autre", "where dm.id = p_demande and l.proprietaire = moi.o_id;", "where dm.id = p_demande;"),
    ("un locataire annule la demande d'un autre", "where id = p_demande and locataire = moi.o_id for update;", "where id = p_demande for update;"),
    ("capacité non vérifiée", "or p_personnes > l.capacite then", "or false then"),
    ("ni verrou ni contrainte d'exclusion",
     "  constraint pas_de_double_reservation exclude using gist\n    (logement_id with =, daterange(debut, fin) with &&) where (statut = 'acceptee')\n",
     "  constraint pas_de_double_reservation check (true)\n"),
    ("date passée acceptée", "if p_debut < (now() at time zone 'Africa/Casablanca')::date then raise exception 'date_passee'; end if;", ""),
    ("le calendrier dit qui", "select coalesce(jsonb_agg(jsonb_build_object('debut', debut, 'fin', fin)", "select coalesce(jsonb_agg(jsonb_build_object('debut', debut, 'fin', fin, 'locataire', 'x')"),
]
# La mutation « ni verrou ni contrainte » retire aussi le verrou d'accepter()
VERROU = "  perform 1 from logements where id = d.logement_id for update;                -- un seul arbitrage à la fois\n"
try:
    for nom, a, b in MUTATIONS:
        if a not in orig:
            print("INTROUVABLE :", nom); continue
        src = orig.replace(a, b, 1)
        if nom.startswith("ni verrou"):
            src = src.replace(VERROU, "")
        F.write_text(src, encoding="utf-8")
        r = subprocess.run(["bash", str(D / "lancer_tests.sh")], capture_output=True, text=True, encoding="utf-8", errors="replace")
        print(("détecté : " if r.returncode else "SURVIT  : ") + nom, flush=True)
finally:
    F.write_text(orig, encoding="utf-8")
