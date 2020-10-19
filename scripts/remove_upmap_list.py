#!/usr/bin/python

import json
import subprocess
import re
import time
import datetime
import sys
import argparse

parser = argparse.ArgumentParser(description='Remove upmaps from a list of pgs on a ceph cluster')
parser.add_argument("scale", help="INT The number of upmaps to remove at each step", type=int)
parser.add_argument("misplaced_max", help="FLOAT The percentage of objects that can be misplaced", type=float)
parser.add_argument("pg_filename", help="STRING File containing pgs with upmaps to remove", type=str)

args = parser.parse_args()

misplaced_threshold = float(args.misplaced_max)
scale = int(args.scale)
pg_filename = str(args.pg_filename)

def rm_pg_upmap( pgs ):
  for pg in pgs:
    print("Removing upmap for pg " + str(pg))
    subprocess.call(["ceph", "osd", "rm-pg-upmap-items", str(pg)])


with open(pg_filename, "r") as pg_file:
  pg_list = pg_file.read().splitlines()

while len(pg_list) > 0:
  # get the health from the cluster
  health = json.loads( subprocess.check_output(["ceph", "health", "-f", "json"]) )
  status = json.loads( subprocess.check_output(["ceph", "status", "-f", "json"]) )

  # check if overall health is not ERR
  if 'ERR' in health['status']:
    print("Exiting! Cluster is in HEALTH_ERR!")
    exit(1)

  # check if there are any OSD_NEARFULL conditions
  if 'OSD_NEARFULL' in health['checks']:
    print("Exiting! Resume when nearfull OSDs have been resolved.")
    exit(1)

  # make sure we're not trying to remove more upmaps than exist
  if scale > len(pg_list):
    scale = len(pg_list)

  # if there are objects misplaced, wait until they're below the threshold
  if 'misplaced_total' in status['pgmap'].keys():
    misplaced_total = int( status['pgmap']['misplaced_total'] )
  else:
    misplaced_total = 0
  if misplaced_total > 0:
    misplaced = float( status['pgmap']['misplaced_ratio'] ) * 100
    print("MISPLACED: " + str(misplaced))
    sys.stdout.flush()

    # if we're ready for upmap removals grab a set to remove
    if misplaced < misplaced_threshold:
      print(str(datetime.datetime.now()) + " Below threshold. Removing " + str(scale) + " upmaps")
      sys.stdout.flush()
      remove_pgs = []
      for x in range(scale):
        remove_pgs.append( pg_list.pop(0) )
      rm_pg_upmap( remove_pgs )
    else:
      print("Waiting, " + str(misplaced) + " > " + str(misplaced_threshold))
      sys.stdout.flush()
  else:
    print(str(datetime.datetime.now()) + " No objects misplaced.  Removing " + str(scale) + " upmaps")
    sys.stdout.flush()
    remove_pgs = []
    for x in range(scale-1):
      remove_pgs.append( pg_list.pop(0) )
    rm_pg_upmap( remove_pgs )

  time.sleep( 60 )

