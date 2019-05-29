#!/bin/bash

printf "\nPG REPORT\n"

printf "\n"
for x in $(ceph osd pool ls); do
  OBJECTS=$(rados df -p $x |head -2 |tail -1 |awk '{print $3}');
  PGS=$(ceph osd pool get $x pg_num |awk '{print $NF}');
  OBJECTS_PER_PG=$(( 100 * $OBJECTS / $PGS));
  OBJECTS_PER_PG=$( echo $OBJECTS_PER_PG |sed 's/..$/.&/' );
  printf "%30s: %15d pgs  %15s total objects  %15s Objects per PG \n" $x $(echo "$PGS")  $(echo -n "$OBJECTS") $( echo "$OBJECTS_PER_PG")
done
