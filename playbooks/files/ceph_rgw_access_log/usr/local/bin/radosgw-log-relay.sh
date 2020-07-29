#!/bin/bash

RGW_LOG_SOCKET=/var/run/ceph/opslog
RSYSLOG_SOCKET=/var/run/ceph/rsyslog-opslog

exec socat -v -u UNIX-CLIENT:${RGW_LOG_SOCKET},type=1 UNIX-CLIENT:${RSYSLOG_SOCKET},type=2

