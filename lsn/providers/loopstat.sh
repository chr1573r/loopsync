#!/bin/bash
# Provider for loopstat
# Pretty much a passthrough for the raw input from lsn,
# but adds epoch timestamp and tab delimiters to comply with expected loopstat input file format

[[ -z "$loopstat_receiver" ]] && echo "loopstat provider error: receiver path not set! please configure with loopstat.cfg in lsn provider dir" && exit 1
! [[ -f "$loopstat_receiver" ]] && echo "loopstat provider error: receiver path wrong or receiver file does not exist! ($loopstat_receiver)" && exit 1

publish(){
    echo -e "$(date +%s)\t${source}\t${category}\t${syncjob}\t${msg}" > "${loopstat_receiver}"
}

source="$1"
category="$2"
syncjob="$3"
msg="$4"

publish 
