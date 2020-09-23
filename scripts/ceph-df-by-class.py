#!/usr/bin/python

import json
import subprocess

def sizeof_fmt(num, suffix='B'):
    for unit in ['','Ki','Mi','Gi','Ti','Pi','Ei','Zi']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)

def get_osd_df_stats():
  osd_df_stats = json.loads( str(subprocess.check_output(["ceph", "osd", "df", "-f", "json"])) )
  return osd_df_stats


osd_df_stats = get_osd_df_stats()

hdd_kb_total = 0
hdd_kb_used = 0
ssd_kb_total = 0
ssd_kb_used = 0
nvme_kb_total = 0
nvme_kb_used = 0

for node in osd_df_stats['nodes']:
  if 'osd' not in node['type']:
    continue
  if 'ssd' in node['device_class']:
    ssd_kb_total += node['kb']
    ssd_kb_used += node['kb_used']
  elif 'hdd' in node['device_class']:
    hdd_kb_total += node['kb']
    hdd_kb_used += node['kb_used']
  elif 'nvme' in node['device_class']:
    nvme_kb_total += node['kb']
    nvme_kb_used += node['kb_used']


print("     %9s %9s %9s" % ( "Total", "Used", "%Used" ))
print("HDD  %9s %9s %9.1f" % ( sizeof_fmt(hdd_kb_total), sizeof_fmt(hdd_kb_used), float(hdd_kb_used)/float(hdd_kb_total)*100 ))
print("SSD  %9s %9s %9.1f" % ( sizeof_fmt(ssd_kb_total), sizeof_fmt(ssd_kb_used), float(ssd_kb_used)/float(ssd_kb_total)*100 ))
print("NVMe %9s %9s %9.1f" % ( sizeof_fmt(nvme_kb_total), sizeof_fmt(nvme_kb_used), float(nvme_kb_used)/float(nvme_kb_total)*100 ))
