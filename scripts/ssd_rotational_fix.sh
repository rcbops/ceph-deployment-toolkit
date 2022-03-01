#!/bin/bash

UDEV_RULE_FILE="/etc/udev/rules.d/60-ssd-nonrotational.rules"
echo "" > /etc/udev/rules.d/60-ssd-nonrotational.rules
VENDOR="$(dmidecode |grep Vendor |awk '{print $2}')"
omreport="/opt/dell/srvadmin/bin/omreport"
ssacli="/usr/sbin/ssacli"

function udev_apply {
    echo "Created ${UDEV_RULE_FILE}"
    cat ${UDEV_RULE_FILE}

    echo
    echo "Applying new udev rules"
    udevadm trigger
    echo

    for DEV in $(cd /dev/; ls sd* |egrep 'sd[a-z][a-z]?$')
    do
        echo -n "${DEV} rotational: "
        cat /sys/class/block/${DEV}/queue/rotational
    done

    echo
    echo "Run \"udevadm trigger\" manually if udev rules look good but rotational values are not set"
}


# Dell
if [ "${VENDOR}" = "Dell" ]
then
    for VDISK in $($omreport storage vdisk |awk '/^ID/ {print $3}');
    do
        PDISKS=$($omreport storage pdisk controller=0 vdisk=${VDISK} |awk -F: '/^ID/ {print $4}' |wc -l);
        if (( $PDISKS == 1 ))
        then
            MEDIA=$($omreport storage vdisk controller=0 vdisk=${VDISK} |awk '/^Media/ {print $3}')
            if [ "${MEDIA}" = "SSD" ]
            then
                BLKDEV=$($omreport storage vdisk controller=0 vdisk=${VDISK} |awk -F\/ '/^Device Name/ {print $NF}')
                echo "# device ${BLKDEV} set rotational for SSD" >> ${UDEV_RULE_FILE}
                SCSIDEV=$(ls /sys/block/${BLKDEV}/device/scsi_device/)
                echo "ACTION==\"add|change\", SUBSYSTEM==\"block\", KERNELS==\"${SCSIDEV}\", ATTR{queue/rotational}=\"0\"" >> ${UDEV_RULE_FILE}
            fi
        fi
    done
    udev_apply
#HP
elif [ "${VENDOR}" = "HP" ] || [ "${VENDOR}" = "HPE" ]
then
    for ARRAY in $($ssacli ctrl slot=3 array all show | awk '/  Array / {print $2}');
    do
        BLKID=$($ssacli ctrl slot=3 array ${ARRAY} ld all show detail | awk '/Disk Name:/ {print $3}'| sed 's/dev\///')
        for PDISK in $($ssacli ctrl slot=3 array ${ARRAY} pd all show | awk '/physicaldrive/ {print $2}');
        do
            MEDIA=$($ssacli ctrl slot=3 array ${ARRAY} pd all show | grep ${PDISK} | awk '{print $8}' | tr -d /,)
            if [ "${MEDIA}" = "SSD" ]
            then
                SCSIDEV=$(ls /sys/block/${BLKID}/device/scsi_device/)
                echo "# device ${BLKID} set rotational for SSD" >> ${UDEV_RULE_FILE}
                echo "ACTION==\"add|change\", SUBSYSTEM==\"block\", KERNELS==\"${SCSIDEV}\", ATTR{queue/rotational}=\"0\"" >> ${UDEV_RULE_FILE}
            fi
        done
    done
    udev_apply
else
echo "Vendor not supported"
fi
