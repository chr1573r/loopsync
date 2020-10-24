#!/bin/bash

# loopstat - dashboard for collecting and viewing loopsync status and statistics
#
# compatible with lsn, but unlike loopsync itself it is not FreeNAS 8 compatible
# however, you can configure a loopsync notifyhook to invoke lsn on a remote machine,
# which can then be picked up by loopstat

# startup
declare -A sync_entries
declare -A host_entries
declare -A metasync_entries
declare -a hostlog_entries

hostname=$(hostname -s)


#fluff functions

init(){
  init_time="$(date +"%d.%m.%y %T")"
  first_run=true
  date_length="${#init_time}"

  trap clean_up SIGINT SIGTERM
  gfx splash

  current_map_prefix="$pmprompt_noformatting @ $(hostname) - Map: "
  current_map_prefix_length="${#current_map_prefix}"
  current_map_prefix="$pmprompt @ $(hostname) - Map: "

  date_prefix="Current time: "
  date_prefix_length="${#date_prefix}"

  last_update_prefix="Last update:  "
  current_mod_date="-"

  gfx init
  gfx render_map_name "(initializing)"
  gfx render_current_time
  gfx render_last_updated



}

clean_up(){
  echo "Caught trap, aborting!"
  reset
  exit
}

# Pretty colors for the terminal:
DEF="\x1b[0m"
WHITE="\e[0;37m"
LIGHTBLACK="\x1b[30;01m"
BLACK="\x1b[30;11m"
LIGHTBLUE="\x1b[34;01m"
BLUE="\x1b[34;11m"
LIGHTCYAN="\x1b[36;01m"
CYAN="\x1b[36;11m"
LIGHTGRAY="\x1b[37;01m"
GRAY="\x1b[37;11m"
LIGHTGREEN="\x1b[32;01m"
GREEN="\x1b[32;11m"
LIGHTPURPLE="\x1b[35;01m"
PURPLE="\x1b[35;11m"
LIGHTRED="\x1b[31;01m"
RED="\x1b[31;11m"
LIGHTYELLOW="\x1b[33;01m"
YELLOW="\x1b[33;11m"

gfx_meta(){
  case "$1" in
    reset)
		reset
		tput civis
		;;
    set_display_properties)
		terminal_width="$(tput cols)"
		terminal_height="$(tput lines)"

		map_viewer_width="$(( terminal_width - 2 ))"
		map_viewer_height="$(( terminal_height - 2 ))"

		log_viewer_header="$(( terminal_height - 12 ))"
		log_viewer_viewport="$(( terminal_height - 11 ))"

		date_field_length="$(( date_prefix_length + date_length ))"
		date_field_startpos="$(( terminal_width - date_field_length ))"
		date_field_time_startpos="$(( terminal_width - date_length ))"
		required_terminal_length="$(( map_info_prefix_length + date_field_time_length ))"
      ;;
    render_header)
	shift
	tput cup 0 0
 	echo -e "${LIGHTBLACK}[${PURPLE}loopstat${LIGHTBLACK}]"
	tput cup 0 "$date_field_startpos"
	echo -n "$date_prefix"
	tput cup 1 "$date_field_startpos"
	echo -ne "$last_update_prefix${DEF}"
	tput cup "$log_viewer_header" 0
	echo -e "${LIGHTBLACK}host status events${DEF}" 
	
	;;
  esac
}

hostlog(){
	tput sc
	tput cup 55 0
	hlog_write_pos=9
	while [[ "$hlog_write_pos" -gt 0 ]]; do
		hlog_read_pos="$(( hlog_write_pos - 1 ))"

		if [[ "${opt}" == "debug" ]]; then echo "replacing $hlog_write_pos : ${hostlog_entries[$hlog_write_pos]} with $hlog_read_pos ${hostlog_entries[$hlog_read_pos]} $(tput el)"; fi
		hostlog_entries[${hlog_write_pos}]="${hostlog_entries[$hlog_read_pos]}"
		(( hlog_write_pos-- ))	
	done
	hostlog_entries[0]="${hostlog_entry}"
	tput rc
}

gfx(){
	case "$1" in
		init)
			gfx_meta reset
			gfx_meta set_display_properties
			gfx_meta render_header
			;;

		condreset)
			if [[ "$(tput cols)" -ne "$terminal_width" ]] || \
			[[ "$(tput lines)" -ne "$terminal_height" ]]; then
				clear
				echo "Resizing terminal.."
				sleep 0.1
				gfx init
				condreset=true
				return 0
			else
				condreset=false
				return 1
			fi
			;;

		render_current_time)
			shift
			tput sc
			tput cup 0 "$date_field_time_startpos"
			echo -en "$(date +"%d.%m.%y %T")"
			tput rc
			;;

		render_last_updated)

			if $condreset; then
				local render=true
			elif [[ "$previous_mod_date" != "$current_mod_date" ]]; then
				local render=true
			else
				local render=false
			fi

			if $render; then
				tput sc
				tput cup 1 "$date_field_time_startpos"
				echo -e "${current_mod_date}$DEF"
				tput rc
				previous_mod_date="$current_mod_date"
			fi
			;;

		host_render)
			shift 1
			host="$1"
			IFS=$'\t' read -r host_timestamp host_source host_status <<< "$(echo -e ${host_entries[$host]})"
			if [[ "${host_status:21:14}" == "Sleeping until" ]]; then # reformat wakeup time if available.
				host_sleep_eta=true
				wakeup="$(date -d "${host_status:36}" +%s)"
				now=$(date +%s)
				time_between_now_and_wakeup="$(( wakeup - now ))"
				if [[ "$time_between_now_and_wakeup" -ge 0 ]]; then
					host_status="${host_status:21}. $time_between_now_and_wakeup seconds remaining"
				elif [[ "$time_between_now_and_wakeup" -lt 0 ]]; then
					host_status="${host_status:21}. ${time_between_now_and_wakeup:1} seconds overslept"
				fi
			else
				host_sleep_eta=false
			fi
			echo -e "${host} \t${host_timestamp}\t \t${host_status}$(tput el)"
		;;

		stat_render)

			
			if $condreset; then
				local render=true
			elif $host_update; then
				local render=true
			elif $syncjob_update; then
				local render=true
			elif $host_sleep_eta; then
				local render=true
			else
				local render=false
			fi

			if $render; then
				tput sc
				tput cup 2 0
				once=true
				for host in "${!host_entries[@]}"; do
					if $once; then
						echo -e "HOST\tTIMESTAMP\tSYNCJOB\tSTATUS$(tput el)"
						echo "$(tput el)"
						once=false
					fi
					gfx host_render "${host}"
					echo "$(tput el)"
					for sync_entry in "${!sync_entries[@]}"; do	
						while IFS=$'\t' read -r timestamp source syncjob message; do
							if [[ "${source}" == "${host}" ]]; then
								case $message in
									'Rsync started')
										message="${GREEN}Syncing${DEF}"
										;;

									'Warning: Rsync exitcode non-zero'|\
									'Warning: Syncmode not recognized, skipping'|\
									'Warning: SSH error, skipping'|\
									'Warning: Ping error, skipping'|\
									'Warning: Could not find cfg file for this sync job, skipping'|\
									'Warning: Cfg file for this sync job is malformed, skipping')
										message="${YELLOW}${message}${DEF}"

								esac
								echo -e " \t$timestamp\t$syncjob\t$message$(tput el)"
							fi
						done < <(echo -e ${sync_entries[${sync_entry}]})
						
					done
					echo "$(tput el)"
				done | column -t -s "$(printf '\t')"
				syncjob_update=false
				tput rc
			fi
			;;

		log_viewer)

			if $condreset; then
				local render=true
			elif $host_update; then
				local render=true
			else
				local render=false
			fi

			if $render; then
				tput sc
				tput cup $log_viewer_viewport 0
				for entry in "${hostlog_entries[@]}"; do 
					tput el
					echo -e "$entry"
				done | column -t -s "$(printf '\t')"
				tput rc
				host_update=false
			fi
			;;

		splash)
			clear
			echo
			echo
			echo
			echo 
			echo
			echo
			echo
			echo -e "        ${LIGHTPURPLE}dP                                        dP              dP   "
			echo -e "        88                                        88              88   "
			echo -e "        88 .d8888b. .d8888b.  88d888b. .d8888b. d8888P .d8888b. d8888P "
			echo -e "        88 88'  \`88 88'  \`88  88'  \`88 Y8ooooo.   88   88'  \`88   88   "
			echo -e "        88 88.  .88 88.  .88  88.  .88       88   88   88.  .88   88   "
			echo -e "        dP \`88888P' \`88888P'  88Y888P' \`88888P'   dP   \`88888P8   dP   "
			echo -e "        ${LIGHTBLACK}ooooooooooooooooooooo~${LIGHTPURPLE}88${LIGHTBLACK}~oooooooooooooooooooooooooooooooooooooo${LIGHTPURPLE}"
			echo -e "                               dP                       Cj Designs 2020${DEF}"
			sleep 0.5
			;;
	esac
}


#main functions
receiver(){
	while read -r timestamp source category syncjob message; do
		if [[ "$timestamp" -ne "$prevstamp" ]]; then
			
			prevstamp="$timestamp"
			metasync_entries[$source$syncjob]="$timestamp"
			tput sc
			tput cup 50 0
			if [[ "${opt}" == "debug" ]]; then echo "receiver: timestamp: '${timestamp}', source: '${source}', category: '${category}', syncjob: '${syncjob}', message: '${message}'$(tput el)"; fi
			timestamp=$(date --date="@$timestamp" +"%d.%m.%y %T")
			if [[ "$category" == "status" ]] || [[ "$category" == "runtime_info" ]] || [[ "$category" == "status" ]]; then
				tput cup 52 0
				if [[ "${opt}" == "debug" ]]; then echo "receiver: host append @ $timestamp: host_entries[$source]=$timestamp\t$source\t$message$(tput el)"; fi
				host_entries[$source]="$timestamp\t$source\t$message"
				hostlog_entry="${source}\t@\t${timestamp}\t${message}"
				current_mod_date="$(date +"%d.%m.%y %T")"
				host_update=true
			elif [[ "$category" == "syncjob" ]]; then
				[[ -z "host_entries[$source]" ]] && host_entries[$source]="placeholder"
				tput cup 53 0
				if [[ "${opt}" == "debug" ]]; then echo "receiver: sync append @ $timestamp: sync_entries[$source$syncjob]=$timestamp\t$source\t$syncjob\t$message$(tput el)"; fi
				sync_entries[$source$syncjob]="$timestamp\t$source\t$syncjob\t$message"
				syncjob_update=true
				current_mod_date="$(date +"%d.%m.%y %T")"
			else
				if [[ "${opt}" == "debug" ]]; then echo "receiver: not recognized @ $timestamp"; fi
			fi
			tput rc
		fi
		
	done < lsreceiver



}


display(){
		
		gfx condreset
		gfx render_current_time
		gfx stat_render 
		gfx render_last_updated
		gfx log_viewer		
}



opt="$1"
#main loop
init
while true; do
	receiver
	if $host_update; then
		hostlog
	fi
	sleep 0.1
	display
	if [[ "${opt}" == "debug" ]]; then
		tput sc
		tput cup 20 0
		echo "sync_entries: ${!sync_entries[*]}"
		echo "host_entries: ${!host_entries[*]}"
		tput rc
	fi
done
