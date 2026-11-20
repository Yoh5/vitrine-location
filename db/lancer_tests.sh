#!/usr/bin/env bash
# Base jetable dans Docker, schéma + données + tous les tests.  Usage : bash db/lancer_tests.sh
set -e
cd "$(dirname "$0")"
C=sakan-db
docker rm -f $C >/dev/null 2>&1 || true
docker run -d --name $C -e POSTGRES_PASSWORD=demo -p 54339:5432 postgres:17-alpine >/dev/null
until docker exec $C pg_isready -U postgres -q 2>/dev/null; do sleep 1; done; sleep 2
P="docker exec -i $C psql -U postgres -v ON_ERROR_STOP=1 -q"
$P < supabase_defauts.sql; $P < schema.sql; $P < api.sql 2>/dev/null; $P < seed.sql; $P < demandes_demo.sql; $P < tests.sql
bash test_concurrence.sh $C
