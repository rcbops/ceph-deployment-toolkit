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

for BUCKET in $BUCKET_LIST; do
    BUCKET_ID=$(${RADOSGW_ADMIN} metadata get bucket:$BUCKET 2>/dev/null| awk -F'"' '/bucket_id/{print $4}')
    if [ -z "${BUCKET_ID}" ]
    then
      echo "Bucket [${BUCKET}] not found"
      echo
      continue
    fi
    echo "${BUCKET}"

    OBJECTS=$(${RADOSGW_ADMIN} bucket stats --bucket=$BUCKET | jq '.usage."rgw.main".num_objects')
    if [ ${OBJECTS} = 'null' ]
    then
        OBJECTS=0
    fi
    echo "Objects: ${OBJECTS}"

    SHARDS=$(${RADOSGW_ADMIN} metadata get bucket.instance:$BUCKET:$BUCKET_ID |jq '.data.bucket_info.num_shards')
    echo "Shards: ${SHARDS}"

    if [ ${SHARDS} -eq 0 ]
    then
        OBJ_PER_SHARD=${OBJECTS}
    else
        OBJ_PER_SHARD=$(( ${OBJECTS}/${SHARDS} ))
    fi

    echo "Objects per Shard: ${OBJ_PER_SHARD}"
    echo
done
