#!/usr/bin/python

import json
import subprocess
import re
import time
import datetime
import sys
import argparse

parser = argparse.ArgumentParser(description='Increase the number of placement groups of a pool in a ceph cluster')
parser.add_argument("pool", help="STRING pool that you are increasing the number of pgs in", type=str)
parser.add_argument("target_number", help="INT the number of pgs you want to end with",type=int)
parser.add_argument("scale", help="INT the amount of pgs to add at each step",type=int)
parser.add_argument("misplaced_max", help="FLOAT The percentage of objects that can be misplaced"type=float)

args = parser.parse_args()

misplaced_threshold = float(args.misplaced_max)
add_pgs = int(args.scale)
pool = str(args.pool)
max_pgs = int(args.target_number)
new_pgs = 0

def get_pool_pgs( pool ):
  pg_stats = json.loads( str(subprocess.check_output(["ceph", "osd", "pool", "get", pool, "pg_num", "-f", "json"])) )
  pool_pgs = int( pg_stats['pg_num'] )
  return pool_pgs

def set_pool_pgs( pool, pgs ):
  subprocess.call(["ceph", "osd", "pool", "set", pool, "pg_num", str(pool_pgs+add_pgs)])
  subprocess.call(["ceph", "osd", "pool", "set", pool, "pgp_num", str(pool_pgs+add_pgs)])


# get the current number of pgs in the target pool
pool_pgs = get_pool_pgs( pool )
print("PGS: " + str(pool_pgs))
sys.stdout.flush()

while pool_pgs < max_pgs:
  # get the health from the cluster
  health = json.loads( subprocess.check_output(["ceph", "health", "-f", "json"]) )
  
  # check if overall health is not ERR
  if 'ERR' in health['overall_status']:
    print("Exiting! Cluster is in HEALTH_ERR!")
    exit(1)

  # if there are objects misplaced, wait until they're below the threshold
  if 'OBJECT_MISPLACED' in health['checks']:
    #print( json.dumps(health['checks']['OBJECT_MISPLACED']['summary']['message']) )
    m = re.search( '\((.*)%\)', health['checks']['OBJECT_MISPLACED']['summary']['message'] )
    misplaced = float( m.group(1) )
    print("MISPLACED: " + str(misplaced))
    sys.stdout.flush()

    # number of pgs to set the pool to
    if (pool_pgs+add_pgs) < max_pgs:
      new_pgs = pool_pgs+add_pgs
    else:
      new_pgs = max_pgs

    # if we're ready for an increase update the pg settings on the pool
    if misplaced < misplaced_threshold:
      print(str(datetime.datetime.now()) + " Below threshold.  Setting pool, " + pool + " pg_num and pgp_num to " + str(new_pgs))
      sys.stdout.flush()
      set_pool_pgs( pool, new_pgs )
    else:
      print("Waiting, " + str(misplaced) + " > " + str(misplaced_threshold))
      sys.stdout.flush()
  else:
    print(str(datetime.datetime.now()) + " No objects misplaced.  Setting pool, " + pool + " pg_num and pgp_num to " + str(new_pgs))
    sys.stdout.flush()
    set_pool_pgs( pool, new_pgs )

  # if we've hit the target quit
  if new_pgs == max_pgs:
    print(str(datetime.datetime.now()) + "Pool " + pool + " set to " + str(max_pgs) + ".  Update complete")
    exit(0)

  pool_pgs = get_pool_pgs( pool )
  time.sleep( 30 )

