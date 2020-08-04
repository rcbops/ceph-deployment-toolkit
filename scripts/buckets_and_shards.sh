#!/bin/bash

for BUCKET in $(radosgw-admin buckets list| awk -F'"' '{print $2}'); do 
    for INSTANCE in $(radosgw-admin metadata get bucket:$BUCKET| awk -F'"' '/bucket_id/{print $4}'); do
        echo "${BUCKET}"

        OBJECTS=$(radosgw-admin bucket stats --bucket=$BUCKET | jq '.usage."rgw.main".num_objects')
        if [ ${OBJECTS} = 'null' ]
        then
            OBJECTS=0
        fi
        echo "Objects: ${OBJECTS}"

        SHARDS=$(radosgw-admin metadata get bucket.instance:$BUCKET:$INSTANCE |jq '.data.bucket_info.num_shards')
        echo "Shards: ${SHARDS}"

        if [ ${SHARDS} -eq 0 ]
        then
            OBJ_PER_SHARD=${OBJECTS}
        else
            OBJ_PER_SHARD=$(( ${OBJECTS}/${SHARDS} ))
        fi
		echo "Objects per Shard: ${OBJ_PER_SHARD}"
	done
    echo
done
