#!/usr/bin/python

import json
import subprocess
import re


def get_insecure_clients():
  ceph_health_detail = json.loads( str(subprocess.check_output(["ceph", "health", "detail", "-f", "json"])) )
  if 'AUTH_INSECURE_GLOBAL_ID_RECLAIM' in ceph_health_detail['checks']:
    insecure_health_detail = ceph_health_detail['checks']['AUTH_INSECURE_GLOBAL_ID_RECLAIM']['detail']

    insecure_clients = {}
    for detail in insecure_health_detail:
      message = detail['message']
      m = re.search('.*\s+at\s+v1:(\S+).*?$', message);
      client = m.group(1)
      insecure_clients[client] = ""
    return insecure_clients
  else:
    print "No clients with AUTH_INSECURE_GLOBAL_ID_RECLAIM"
    exit(0)

def get_rbd_pools():
  ceph_rbd_pools_detail = json.loads( str(subprocess.check_output(["ceph", "osd", "pool", "ls", "detail", "-f", "json"])) )
  rbd_pools = []
  for pool in ceph_rbd_pools_detail:
    if 'rbd' in pool['application_metadata']:
      rbd_pools.append(pool['pool_name'])
  return rbd_pools

def get_rbd_client_volumes( pools ):
  rbd_client_volumes = {}
  for pool in pools:
    sp = subprocess.Popen(["rbd", "-p", pool, "ls"], stdout=subprocess.PIPE)
    rbd_volumes = []
    for line in sp.stdout.readlines():
      rbd_volumes.append(line.strip('\n'))
    for volume in rbd_volumes:
      # print volume
      status = subprocess.check_output(["rbd", "status", pool+"/"+volume]) #, stdout=subprocess.PIPE)
      m = re.search('watcher=(\S+)\s+', status);
      if m is not None:
        watcher = m.group(1)
        rbd_client_volumes[watcher] = pool+"/"+volume
  return rbd_client_volumes


# get insecure clients from cluster health
insecure_clients = get_insecure_clients()
#print insecure_clients

# get all RBD pools
rbd_pools = get_rbd_pools()
#print rbd_pools

# get all RBD volumes and clients
rbd_client_volumes = get_rbd_client_volumes( rbd_pools )
#print rbd_client_volumes

for insecure_client in insecure_clients:
  print insecure_client + " " + rbd_client_volumes[insecure_client]
