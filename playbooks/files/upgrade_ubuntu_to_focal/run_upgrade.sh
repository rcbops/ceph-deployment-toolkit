#!/bin/bash

# check that we're on 18.04
VERSION=$(lsb_release -sr)
if [ "${VERSION}" != "18.04" ]
then
  >&2 echo "Ubuntu version must be 18.04.  Current version is ${VERSION}"
  exit 1
fi

# check if any upgrades have recently been run that require reboot
# (this should also be checked by do-release-upgrade)
if [ -f /var/run/reboot-required ]
then
  >&2 echo "Reboot required before do-release- upgrade"
  exit 1
fi

# make sure do-release-upgrade isn't already running
pgrep -f do-release-upgrade >/dev/null
if [ $? -ne 1 ]
then
  >&2 echo "do-release-upgrade is already running!"
  exit 1
fi

# run do-release-upgrade and log output
/usr/bin/python3 -u /usr/bin/do-release-upgrade -m server -f DistUpgradeViewNonInteractive 2>&1 | tee /var/log/release-upgrade_$( date +%F ).log

