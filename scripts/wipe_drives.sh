#!/bin/bash

if [ "$#" -lt 1 ]
then
  echo "Usage: `basename $0` [/dev/sdx] [/dev/sdy] ..."
  exit 1
fi

# install gdisk
apt install -y gdisk

# remove ceph logical volumes
for LV in $(lvs |grep ceph |awk '{print $2"/"$1}')
do
  lvremove -y ${LV}
done

# remove ceph volume groups
for VG in $(vgs |awk '/ceph/ {print $1}')
do
  vgremove -y ${VG}
done

# remove ceph physical volumes
for PV in "$@"
do
  #pvremove ${PV}
  echo ${PV}
done

exit

# wipe drive partitions and overwrite first 200M of each drive
for DEV in "$@"
do
  sgdisk --zap-all --clear --mbrtogpt -g -- ${DEV}
  dd if=/dev/zero of=${DEV} bs=1M count=200
done
