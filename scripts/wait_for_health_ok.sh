#!/bin/bash
# Wait until ceph has a status of HEALTH_OK (or ERR)
#
# Accepts a single, optional, parameter of time (in seconds) to wait between 
# checks.  Defaults to 60 seconds.
#
# If the cluster reaches a HEALTH_ERR status, then the script terminates 
# with an exit code of 1.  
# If the cluster reaches a HEALTH_OK status, the script terminates with 
# an exit code  of zero. 
#

# if check_interval is not specified, default to 60
check_interval=${1:-60}

# don't allow check_interval to be less than 1
if [[ $check_interval -lt 1 ]]; then
  check_interval=1
fi
 
while [[ "$(ceph health)" == HEALTH_WARN* ]] ; do
  sleep $check_interval
done

if [[ "$(ceph health)" == HEALTH_OK* ]]; then
  exit 0
else
  exit 1
fi
