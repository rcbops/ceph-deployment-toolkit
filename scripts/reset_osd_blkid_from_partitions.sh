#!/bin/bash

for x in /dev/sd{b..o}
do
    mount ${x}1 /mnt
    OSD_ID=$(cat /mnt/whoami)
    umount /mnt
    mount ${x}1 /var/lib/ceph/osd/ceph-${OSD_ID}

    PART_UUID=$(blkid ${x}2 |awk '{print $NF}' |sed -e 's/PARTUUID=//' |sed -e 's/"//g')
    echo $PART_UUID

    echo $PART_UUID > /var/lib/ceph/osd/ceph-${OSD_ID}/block_uuid
    chown ceph:ceph /var/lib/ceph/osd/ceph-${OSD_ID}/block_uuid

    rm /var/lib/ceph/osd/ceph-${OSD_ID}/block
    ln -s /dev/disk/by-partuuid/${PART_UUID} /var/lib/ceph/osd/ceph-${OSD_ID}/block
    chown ceph:ceph /var/lib/ceph/osd/ceph-${OSD_ID}/block

    umount /var/lib/ceph/osd/ceph-${OSD_ID}
done
