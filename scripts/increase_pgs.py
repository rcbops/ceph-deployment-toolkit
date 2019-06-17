#!/usr/bin/python

import json
import subprocess
import re
import time
import datetime
import sys

misplaced_threshold = 2.0
add_pgs = 1
pool = 'default.rgw.buckets.data'
max_pgs = 1024


def get_pool_pgs( pool ):
  pg_stats = json.loads( subprocess.check_output(["ceph", "osd", "pool", "get", pool, "pg_num", "-f", "json"]) )
  pool_pgs = int( pg_stats['pg_num'] )
  return pool_pgs

def set_pool_pgs( pool, pgs ):
  subprocess.call(["ceph", "osd", "pool", "set", pool, "pg_num", str(pool_pgs+add_pgs)])
  subprocess.call(["ceph", "osd", "pool", "set", pool, "pgp_num", str(pool_pgs+add_pgs)])


# get the current number of pgs in the target pool
pool_pgs = get_pool_pgs( pool )
print "PGS: " + str(pool_pgs)
sys.stdout.flush()

while pool_pgs < max_pgs:
  # get the health from the cluster
  health = json.loads( subprocess.check_output(["ceph", "health", "-f", "json"]) )

  # if there are objects misplaced, wait until they're below the threshold
  if 'OBJECT_MISPLACED' in health['checks']:
    #print( json.dumps(health['checks']['OBJECT_MISPLACED']['summary']['message']) )
    m = re.search( '\((.*)%\)', health['checks']['OBJECT_MISPLACED']['summary']['message'] )
    misplaced = float( m.group(1) )
    print "MISPLACED: " + str(misplaced)
    sys.stdout.flush()

    # number of pgs to set the pool to
    if (pool_pgs+add_pgs) < max_pgs:
      new_pgs = pool_pgs+add_pgs
    else:
      new_pgs = max_pgs

    # if we're ready for an increase update the pg settings on the pool
    if misplaced < misplaced_threshold:
      print str(datetime.datetime.now()) + " Below threshold.  Setting pool, " + pool + " pg_num and pgp_num to " + str(new_pgs)
      sys.stdout.flush()
      set_pool_pgs( pool, new_pgs )
    else:
      print "Waiting, " + str(misplaced) + " > " + str(misplaced_threshold)
      sys.stdout.flush()
  else:
    print str(datetime.datetime.now()) + " No objects misplaced.  Setting pool, " + pool + " pg_num and pgp_num to " + str(new_pgs)
    sys.stdout.flush()
    set_pool_pgs( pool, new_pgs )

  # if we've hit the target quit
  if new_pgs == max_pgs:
    print str(datetime.datetime.now()) + "Pool " + pool + " set to " + max_pgs + ".  Update complete"
    exit

  pool_pgs = get_pool_pgs( pool )
  time.sleep( 30 )
