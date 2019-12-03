#!/bin/bash

# This script grabs the number of placement groups in each pool and provides the following information 
#    - the number of placement groups in each pool
#    - the number of objects in each pool
#    - the number of objects per placement group in each pool
#
# The output is formatted for easy copypasta into tickets

echo -e "\nPG REPORT\n"
echo '                          Pool        PGs         Objects  Objects per PG'
echo '------------------------------ ---------- --------------- ---------------'

ceph df -f json | jq -r -c '.pools[]' | while IFS='' read pool; do
  NAME="$(echo $pool | jq -r '.name')"
  OBJECTS=$(echo $pool | jq '.stats.objects')
  PGS=$(ceph osd pool get $NAME pg_num | awk '{print $NF}')
  OBJECTS_PER_PG=$(echo "scale=2; $OBJECTS / $PGS" | bc)
  printf "%30s %10d %15s %15s \n" "$NAME"  "$PGS"  "$OBJECTS" "$OBJECTS_PER_PG"
done
