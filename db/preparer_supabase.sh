#!/usr/bin/env bash
# Un seul fichier à coller dans l'éditeur SQL d'un projet Supabase NEUF : schéma + données de démonstration.
# (supabase_defauts.sql, api.sql et jeton_local.py ne servent qu'en local.)
set -e
cd "$(dirname "$0")"
{ echo "-- Généré par preparer_supabase.sh le $(date -u +%Y-%m-%dT%H:%MZ). Ne pas modifier ici."
  cat schema.sql seed.sql demandes_demo.sql; } > supabase_complet.sql
echo "db/supabase_complet.sql prêt ($(wc -l < supabase_complet.sql) lignes)"
