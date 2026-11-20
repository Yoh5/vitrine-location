#!/usr/bin/env bash
# API REST locale (PostgREST, la même que Supabase) devant la base de lancer_tests.sh, avec jetons signés.
set -e
cd "$(dirname "$0")"
docker exec -i sakan-db psql -U postgres -q < api.sql
docker exec -i sakan-db psql -U postgres -q -c "grant authenticated to authenticator;"
docker network create sakan >/dev/null 2>&1 || true
docker network connect sakan sakan-db 2>/dev/null || true
docker rm -f sakan-api >/dev/null 2>&1 || true
docker run -d --name sakan-api --network sakan -p 54331:3000 \
  -e PGRST_DB_URI="postgres://authenticator:demo@sakan-db:5432/postgres" \
  -e PGRST_DB_SCHEMAS=public -e PGRST_DB_ANON_ROLE=anon \
  -e PGRST_JWT_SECRET=secret-local-de-developpement-32-caracteres-au-moins postgrest/postgrest:latest >/dev/null
echo "API sur http://localhost:54331"
