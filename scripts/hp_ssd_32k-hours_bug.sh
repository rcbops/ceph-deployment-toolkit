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
TEMP_DRIVES=$( mktemp /tmp/temptest.XXXXXXX )
for SLOT in $( ${SSACLI} controller all show config |awk '/in Slot/ {print $6}' )
do
  ${SSACLI} controller slot=${SLOT} pd all show detail |awk '/Model/ {print $3}' >> ${TEMP_DRIVES}
done

# check for affected drives and provide counts
egrep "${AFFECTED_MODELS}" ${TEMP_DRIVES} |unic -c

# clean up
rm ${TEMP_DRIVES}
