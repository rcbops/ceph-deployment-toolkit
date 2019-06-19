#!/bin/bash
#
# Print rbd images that are consuming a specific osd
# usage ./finger_of_blame.sh -p <pool> -o <id>
# <pool> - the pool to check 
# <id> - the osd id that is experiencing slow requests

usage="finger_of_blame.sh

where:
  -h show this helpful text
  -p <pool> 
  -o <id>"

while getopts 'hp:o:' opt; do
    case "$opt" in
        h) echo "$usage"
           exit
           ;;
        p) pool=$OPTARG
           ;;
        o) osd_id=$OPTARG
           ;;
        :) printf "missing arguement for -%s\n" "$OPTARG" >&2
           echo "$usage" >&2
           exit 1
           ;;
       \?) printf "you can't use -%s\n" "$OPTARG" >&2
           echo "$usage" >&2
           exit 1
           ;;
    esac
done

for prefix in $(bash rbdtop.sh -l 300 -o $osd_id | grep "rbd_data" | awk '{ print $2 }' | uniq)
do
    for volume in $(rbd -p $pool ls)
    do
        if $(rbd -p $pool info $volume | grep -q $prefix);
        then
            rbd info -p $pool $volume | grep "rbd image" | awk '{ print $3 }' | sed 's\_disk'\'':\\' 
        fi
    done
done

