#!/bin/bash

function help {
   echo "buckets_and_shards.sh [bucket] [bucket...]"
   exit 0
}

RADOSGW_ADMIN=$(which radosgw-admin)
if [ -z "$RADOSGW_ADMIN" ]
then
    echo "Couldn't find radosgw-admin command!"
    exit 1
fi

RADOS=$(which rados)
if [ -z "$RADOS" ]
then
    echo "Couldn't find rados command!"
    exit 1
fi

let -a BUCKET_LIST

if [ $# -ne 0 ]
then
    if [ $1 = "-h" ]
    then
        help
    fi

    BUCKET_LIST=$@
else
    BUCKET_LIST=$(${RADOSGW_ADMIN} buckets list| awk -F'"' '{print $2}')
fi

TMPFILE=$(mktemp /tmp/check_shard_distribution.XXXXXX)

INDEX_POOL_ID=$(ceph osd pool ls detail |awk '/default.rgw.buckets.index/ {print $2}')


for BUCKET in $BUCKET_LIST; do
    BUCKET_ID=$(${RADOSGW_ADMIN} metadata get bucket:$BUCKET 2>/dev/null| awk -F'"' '/bucket_id/{print $4}')
    if [ -z "${BUCKET_ID}" ]
    then
      echo "Bucket [${BUCKET}] not found"
      echo
      continue
    fi
    echo "${BUCKET}"

    All_SHARDS=""
    TOTAL_PGS=0
    USED_PGS=0
    for PG in $(ceph pg ls |awk "/^${INDEX_POOL_ID}/ {print \$1}")
    do
	NUM_SHARDS=$(${RADOS} --pgid $PG --pool default.rgw.buckets.index ls |grep ${BUCKET_ID} |wc -l)
        echo -n "${PG}: ${NUM_SHARDS}"
	echo
	ALL_SHARDS="$NUM_SHARDS $ALL_SHARDS"
	TOTAL_PGS=$(( $TOTAL_PGS + 1 ))
	if [ $NUM_SHARDS -gt 0 ]
        then
            USED_PGS=$(( $USED_PGS + 1 ))
	fi
    done

    TOTAL_SHARDS=$( echo "${ALL_SHARDS}" |tr [:space:] '\n' | awk '{sum+=$1}END{print sum}' )
    stdDev=$( echo "${ALL_SHARDS}" |tr [:space:] '\n' | awk '{sum+=$1; sumsq+=$1*$1}END{print sqrt(sumsq/NR - (sum/NR)**2)}' )
    echo "Total PGs: ${TOTAL_PGS}"
    echo "Used PGs: ${USED_PGS}"
    echo "Total Shards: ${TOTAL_SHARDS}"
    echo "Standard Deviation: ${stdDev}"
    echo
done
