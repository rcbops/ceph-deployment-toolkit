#!/bin/bash

UDEV_RULE_FILE="/etc/udev/rules.d/60-ssd-nonrotational.rules"

VENDOR="$(dmidecode |grep Vendor |awk '{print $2}')"

# Dell
if [ "${VENDOR}" = "Dell" ]
then
    for VDISK in $(omreport storage vdisk |awk '/^ID/ {print $3}');
    do
        PDISKS=$(omreport storage pdisk controller=0 vdisk=${VDISK} |awk -F: '/^ID/ {print $4}' |wc -l);
        if (( $PDISKS == 1 ))
        then
            MEDIA=$(omreport storage vdisk controller=0 vdisk=${VDISK} |awk '/^Media/ {print $3}')
            if [ "${MEDIA}" = "SSD" ]
            then
                BLKDEV=$(omreport storage vdisk controller=0 vdisk=${VDISK} |awk -F\/ '/^Device Name/ {print $NF}')
                echo "# device ${BLKDEV} set rotational for SSD" >> ${UDEV_RULE_FILE}
                SCSIDEV=$(ls /sys/block/${BLKDEV}/device/scsi_device/)
                echo "ACTION==\"add|change\", SUBSYSTEM==\"block\", KERNELS==\"${SCSIDEV}\", ATTR{queue/rotational}=\"0\"" >> ${UDEV_RULE_FILE}
            fi
        fi
    done
fi
