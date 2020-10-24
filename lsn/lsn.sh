#!/bin/bash
# lsn - loopsync notification
#
# Message broker that converts Loopsync notifyhooks into human readable messages.
#
# lsn supports a fan-out design using "providers", so that you can publish a single notification to multiple, different targets (e.g slack, loopstat)

lsn_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

init(){
    if ! [[ -f "${lsn_dir}/lsn.cfg" ]]; then
        echo "lsn error: lsn configuration file not found!"
    else
        source "${lsn_dir}/lsn.cfg"
    fi

    if [[ -z "${lsn_providers}" ]]; then
        echo "lsn configuration error: no providers configured!"
        exit 1
    fi

    if [[ "${lsn_providers[0]}" == "all" ]]; then
        provider_id=0
        for provider in $(ls -f $lsn_dir/providers/*.sh); do
            lsn_providers[${provider_id}]="$(basename ${provider} .sh)"
            ((provider_id++))
        done
    fi     
}



determine_source(){
    source=$(cut -d' ' -f1 <<< "$SSH_CLIENT")
    if ! [[ -z "$SSH_CLIENT" ]]; then
        digresult=$(dig +short -x $SSH_CLIENT)
        if [[ "$?" -eq 0 ]] && ! [[ -z "$digresult" ]]; then
            source="$digresult"
        fi
    else
        source="$(hostname)"
    fi
}


parser(){
    syncjob=none # Syncjob defaults to none unless overridden during parsing
    case "$1" in
        startup|sleep|wakeup|break|shutdown) #runtime change notification, no additional parameters
            category=runtime_info
            [[ "$1" == startup ]] && msg="Loopsync starting up"
            [[ "$1" == sleep ]] && msg="Entering sleep mode. Sleeping until $(date -d "$2 seconds")"
            [[ "$1" == wakeup ]] && msg="Waking up (waking up inside)"
            [[ "$1" == break ]] && msg="Break"
            [[ "$1" == shutdown ]] && msg="Shutting down"
            ;;
            
        Idle|Busy|Sync|HALT) #status change notifications, no additional parameters
            category=status
            msg="$1"
            ;;

        sync_list_not_found) # sync list file not found, path as parameter
            category=sync_list_not_found
            msg="Fatal: Could not find synclist $2"
            ;;

        current_sync|rsync_start|rsync_ok|rsync_error|invalid_mode|ssh_error|ping_error|sync_dataset_not_found|sync_dataset_incomplete) # syncjob specific, dataset as parameter
            category=syncjob
            syncjob="$2"
            [[ "$1" == current_sync ]] && msg="Preparing sync"
            [[ "$1" == rsync_start ]] && msg="Rsync started"
            [[ "$1" == rsync_ok ]] && msg="Rsync finished"
            [[ "$1" == rsync_error ]] && msg="Warning: Rsync exitcode non-zero"
            [[ "$1" == invalid_mode ]] && msg="Warning: Syncmode not recognized, skipping"
            [[ "$1" == ssh_error ]] && msg="Warning: SSH error, skipping"
            [[ "$1" == ping_error ]] && msg="Warning: Ping error, skipping"
            [[ "$1" == sync_dataset_not_found ]] && msg="Warning: Could not find cfg file for this sync job, skipping"
            [[ "$1" == sync_dataset_incomplete ]] && msg="Warning: Cfg file for this sync job is malformed, skipping"
            ;;
    esac

}

notification(){
    for provider in "${lsn_providers[@]}"; do
        [[ -f "${lsn_dir}/providers/$provider.cfg" ]] && source "${lsn_dir}/providers/$provider.cfg"
        bash "${lsn_dir}/providers/$provider.sh" "$source" "$category" "$syncjob" "$msg"
    done
}

init
determine_source
parser "$@"
notification
