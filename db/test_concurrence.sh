#!/usr/bin/env bash
# Deux onglets du propriétaire acceptent EN MÊME TEMPS deux demandes qui se chevauchent (riad, Salma et Mehdi).
# L'onglet A garde sa transaction ouverte 3 s ; B arrive pendant ce temps.
# Attendu : un seul séjour accepté, l'autre demande refusée (d'office ou par « deja_close »), jamais deux acceptés.
set -u
C=${1:-sakan-db}
P="docker exec -i $C psql -U postgres -q -t -A"
CO="select set_config('request.jwt.claims', '{\"sub\":\"11111111-0000-0000-0000-000000000001\",\"role\":\"authenticated\"}', false);"
S=$($P -c "select id from demandes where logement_id = 3 and locataire = '22222222-0000-0000-0000-000000000003'")
M=$($P -c "select id from demandes where logement_id = 3 and locataire = '22222222-0000-0000-0000-000000000004'")
($P -c "set role authenticated; $CO begin; select accepter($S); select pg_sleep(3); commit;" > /tmp/sa.out 2>&1) &
sleep 1
($P -c "set role authenticated; $CO select accepter($M);" > /tmp/sb.out 2>&1) &
wait
acc=$($P -c "select count(*) from demandes where logement_id = 3 and statut = 'acceptee'")
ref=$($P -c "select count(*) from demandes where logement_id = 3 and statut = 'refusee'")
echo "séjours acceptés sur le riad : $acc, refusés : $ref ; onglet B : $(grep -o 'deja_close\|dates_indisponibles\|"statut" *: *"acceptee"' /tmp/sb.out | head -1)"
if [ "$acc" = 1 ] && [ "$ref" = 1 ]; then echo "Concurrence (deux acceptations) : OK"; else echo "Concurrence : ÉCHEC"; cat /tmp/sa.out /tmp/sb.out; exit 1; fi

# Le propriétaire bloque des dates pendant qu'une acceptation est en cours sur ces mêmes dates.
$P -c "insert into demandes (logement_id, locataire, debut, fin, personnes, prix_total, detail_prix)
       values (2, '22222222-0000-0000-0000-000000000002', current_date + 70, current_date + 75, 1, 1750, '{}')" >/dev/null
D=$($P -c "select max(id) from demandes")
($P -c "set role authenticated; $CO begin; select accepter($D); select pg_sleep(3); commit;" > /tmp/sc.out 2>&1) &
sleep 1
($P -c "set role authenticated; $CO select bloquer(2, current_date + 72, current_date + 74, 'travaux');" > /tmp/sd.out 2>&1) &
wait
acc=$($P -c "select count(*) from demandes where logement_id = 2 and statut = 'acceptee' and debut = current_date + 70")
blo=$($P -c "select count(*) from indisponibilites where logement_id = 2 and debut = current_date + 72")
echo "séjour accepté : $acc, blocage posé par-dessus : $blo"
if [ "$acc" = 1 ] && [ "$blo" = 0 ] && grep -q dates_indisponibles /tmp/sd.out; then echo "Concurrence (acceptation contre blocage) : OK"; else echo "Concurrence : ÉCHEC"; cat /tmp/sc.out /tmp/sd.out; exit 1; fi
