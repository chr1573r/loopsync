#!/bin/bash
# Test provider for lsn - just returns whatever was passed to it + configured option

publish(){
    echo "loopback[cfg: ${loopback_param}]: source:$source, category:$category, syncjob:$syncjob, msg:$msg"
}

source="$1"
category="$2"
syncjob="$3"
msg="$4"

publish
