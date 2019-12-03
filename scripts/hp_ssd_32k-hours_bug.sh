#!/bin/bash

# List of drive models affected by the firmware bug that causes SSDs running >32k hours to die
# https://support.hpe.com/hpsc/doc/public/display?docId=emr_na-a00092491en_us
AFFECTED_MODELS="VO0480JFDGT|VO0960JFDGU|VO1920JFDGV|VO3840JFDHA|MO0400JFFCF|MO0800JFFCH|MO1600JFFCK|MO3200JFFCL|VO000480JWDAR|VO000960JWDAT|VO001920JWDAU|VO003840JWDAV|VO007680JWCNK|VO015300JWCNL|VK000960JWSSQ|VK001920JWSSR|VK003840JWSST|VK003840JWSST|VK007680JWSSU|VO015300JWSSV"

# find the installed ssacli tool
SSACLI="$(which ssacli 2>/dev/null)"
if [ -z "${SSACLI}" ]
then
  SSACLI="$(which hpssacli 2>/dev/null)"
fi

if [ -z "${SSACLI}" ]
then
  echo "Couldn't find (hp)ssacli tool!"
  exit 1
fi


# collect all drive models on the system
TEMP_DRIVES=$( mktemp /tmp/hp_drives.XXXXXXX )
for SLOT in $( ${SSACLI} controller all show config |awk '/in Slot/ {print $6}' )
do
  ${SSACLI} controller slot=${SLOT} pd all show detail |awk '/Model/ {print $3}' >> ${TEMP_DRIVES}
done

# check for affected drives and provide counts
if [ $(cat ${TEMP_DRIVES} |wc -l) -gt 0 ]
then
  echo "Detected affected drive models, firmware HPD8 may be required"
  egrep "${AFFECTED_MODELS}" ${TEMP_DRIVES} |uniq -c
  echo

  for SLOT in $( ${SSACLI} controller all show config |awk '/in Slot/ {print $6}' )
  do
    for PD in $( hpssacli controller slot=${SLOT} pd all show |awk '/physicaldrive/ {print $2}' )
    do
      TEMP_DRIVE_DETAIL=$( mktemp /tmp/hp_drive_detail.XXXXXXX )
      ${SSACLI} controller slot=${SLOT} pd ${PD} show detail >> ${TEMP_DRIVE_DETAIL}
      if [ $(egrep "${AFFECTED_MODELS}" ${TEMP_DRIVE_DETAIL} |wc -l) -gt 0 ]
      then
        MODEL=$(awk '/Model/ {print $NF}' ${TEMP_DRIVE_DETAIL})
        FIRMWARE=$(awk '/Firmware/ {print $NF}' ${TEMP_DRIVE_DETAIL})
        echo "slot=${SLOT} pd ${PD}: model ${MODEL} firmware ${FIRMWARE}"
      fi
      rm ${TEMP_DRIVE_DETAIL}
    done
  done
fi

# clean up
rm ${TEMP_DRIVES}
