#!/usr/bin/env bash
# Restart all OSDs in the cluster, one-at-a-time, waiting for the cluster to 
# return to HEALTH_OK between osd restarts.
#
# This must be run from a "deployment" server, which has /etc/hosts (or DNS, 
# or ssh-config, or something) to allow it to ssh "by hostname".  We also 
# assume that ssh-keys are set up to allow ssh logins into each osd node 
# without a password.

all_osds="$(ceph osd dump | egrep '^osd' | egrep -o 'osd\.[0-9]{1,} ')"

for osd in $all_osds; do
  # find the host on which this OSD resides
  host="$(ceph osd find $osd | jq '.host' | sed 's/"//g')"

  # strip out just the OSD number
  osd_num="$(echo $osd | sed 's/osd\.//')"

  echo "restarting $osd on $host"
 
  # log into the host and restart the osd
  ssh $host systemctl restart ceph-osd@${osd_num}

  # blindly wait a little while to allow the cluster to 
  # update its status reporting.
  sleep 10

  # wait until the cluster returns to HEALTH_OK
  ./wait_for_health_ok.sh 2
done
