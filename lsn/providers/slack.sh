#!/bin/bash
# Slack provider for lsn
# Sends lsn notifications to a Slack channel using standard Slack webhooks
# Applies some message formatting and also ignores 'status' notifyhooks to avoid being too chatty
#
# Add slack channel and slack webhook url to slack.cfg
#
notification(){
    case "$1" in
        runtime_info|sync_list_not_found)
            publish "*${source}* ${2}"
            ;;
        syncjob)
            publish "*${source}[ _${syncjob}_ ]* ${2}"
            ;;
    esac
}

publish(){
    curl -s -X POST --data-urlencode "payload={\"channel\": \"#${slack_channel}\", \"text\": \"$1\"}" "${slack_url}" >/dev/null
    [[ "$?" -ne 0 ]] && echo "Slack provider error: curl returned non-zero error code"
}


[[ -z "${slack_channel}" ]] && echo "Slack provider error: Slack channel not configured" && exit 1
[[ -z "${slack_url}" ]] && echo "Slack provider error: Slack webhook url not configured" && exit 1

source="$1"
category="$2"
syncjob="$3"
msg="$4"

notification "$category" "$msg"