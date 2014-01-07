#!/bin/bash
# loopsync.sh - rsync replication script
# WARNING - This code is not necessarily safe on your system, use at your own responibility!
# Written by Christer Jonassen - cjdesigns.no
# Licensed under CC BY-NC-SA 3.0 (check LICENCE file or http://creativecommons.org/licenses/by-nc-sa/3.0/ for details.)
# Made possible by the wise *nix and BSD people sharing their knowledge online
#
# Check README for instructions

# Variables
APPVERSION="2.0"
STATUS=""$DEF"Idle"

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

##################
# FUNCTIONS BEGIN:

timeupdate() # Sets current time into different variables. Used for timestamping etc.
{
	DATE=$(date +"%d-%m-%Y") 			# 12-04-2013 (day-month-year)
	SHORTDATE=$(date +"%d-%m-%y")		# 12-04-13
	TINYDATE=$(date +"%Y%m%d")			# 20130412
	DATEFUZZY=$(date +"%a %d %b")		# Fri 12 Apr
	MCSTAMP=$(date +"%Y-%m-%d %R:%S")	# 2013-04-12 15:34:13 (mc server log format)
	UNIXSTAMP=$(date +%s)				# 1365773648 (unix timestamp)
	NOWSTAMP=$(date +"%Hh%Mm%Ss") 		# 15h34m34s
	HM=$(date +"%R") 					# 15:34
	HMS=$(date +"%R:%S") 				# 15:34:34
	HOUR=$(date +"%H") 					# 15
	MINUTE=$(date +"%M") 				# 34
	SEC=$(date +"%S") 					# 56
}


ut()
{
	echo -e ""$LIGHTGRAY"["$DEF""$GREEN"ls"$LIGHTGRAY"]"$DEF"[$STATUS][$(date +"%a %d %b, %R:%S")]"$LIGHTYELLOW":"$DEF" $1"
	logg "$1"
	if [ "$2" == "slow" ]; then sleep 0.5; fi

}


status()
{
	case "$1" in
		idle)
		STATUS=""$DEF"Idle"
		CLEARTEXTSTATUS="Idle"
		RHOST="<idle>"
		;;

		busy)
		STATUS=""$YELLOW"Busy"$DEF""
		CLEARTEXTSTATUS="Busy"
		;;

		sync)
		STATUS=""$LIGHTGREEN"Sync"$DEF""
		CLEARTEXTSTATUS="Sync"
		;;

		error)
		STATUS=""$LIGHTRED"HALT"$DEF""
		CLEARTEXTSTATUS="HALT"
		;;
	esac
	logg "Status set to $1"
}


logg()
{
timeupdate
		echo "$MCSTAMP [$CLEARTEXTSTATUS][$RHOST] $1">>lsync.log
}


splash() # display logo
{
	clear
	echo
	echo
	echo
	echo 
	echo
	echo
	echo
	echo -e "        "$GREEN"dP                                                                "
	echo -e "        88                                                               "$LIGHTGREEN"v2"$DEF""$GREEN""
	echo -e "        88 .d8888b. .d8888b. 88d888b. .d8888b. dP    dP 88d888b. .d8888b. "
	echo -e "        88 88'  \`88 88'  \`88 88'  \`88 Y8ooooo. 88    88 88'  \`88 88'  \`"" "
	echo -e "        88 88.  .88 88.  .88 88.  .88       88 88.  .88 88    88 88.  ... "
	echo -e "        dP \`88888P' \`88888P' 88Y888P' \`88888P' \`8888P88 dP    dP \`88888P' "
	echo -e "        "$GRAY"oooooooooooooooooooo~"$GREEN"88"$GRAY"~oooooooooooooooo~~~~"$GREEN".88"$GRAY"~ooooooooooooooooo"
	echo -e "        "$GREEN"                      dP                 d8888P   "$LIGHTBLACK"Cj Designs 2014"$DEF""
}


modeselect() # Determine push or pull and sets variables based on which way we are interacting with the remote system
{
	case "$PUSHPULL" in
		
		push)
			RHOST=$TARGETSYSTEM
			PUSHPULL=PUSH
			;;
		
		PUSH)
			RHOST=$TARGETSYSTEM
			;;
		
		pull)
			RHOST=$SOURCESYSTEM
			PUSHPULL=PULL
			;;
		
		PULL)
			RHOST=$SOURCESYSTEM
			;;
		
		*)
			status error
			ut "Value of \$PUSHPULL was not recognized as \"PUSH\" or \"PULL\"."
			ut "Please correct this in the cfg file $CURRENTDATASET"
			exit
			;;
	esac
}


checkping() # Check if remote system is pingable
{
	ut "   Attempting ping..."
	ping -q -c 4 -W3 $RHOST&> /dev/null # Ping remote host 4 times, with a timeout of 3 seconds
		if [ $? == 0 ]; then
			ut "     -> Target is "$GREEN"pingable"$DEF"!"
		else
			CONCHECK="ERR"
			status error
			ut "     -> Target is "$RED"not pingable"$DEF""
			sleep 2
		fi
}


checkssh()
{
	ut "   Attempting SSH connection..."
	ssh -n -i $KEY -p $PORT -q $REMOTEUSER@$RHOST exit
		if [ $? == 0 ]; then
			ut "     -> SSH test connection "$GREEN"successful"$DEF"!"
		else
			CONCHECK="ERR"
			status error
			ut "     -> SSH test connection "$RED"unsuccessful"$DEF""
			sleep 2
		fi
}


idlewait()
{
	ut "Checking if loopsleep.txt is present.."
	if [ -f loopsleep.txt ]; 
		then status idle
		ut "Entering deep sleep (loopsleep.txt detected)"

		ut "Waiting until told otherwise. Re-checking for go-signal every "$LIGHTGRAY"$CHECKINTERVAL"$DEF" second(s)"
		while [ -f loopsleep.txt ]
		do
			COUNTDOWN=$CHECKINTERVAL
			until [ $COUNTDOWN == 0 ]; do
				sleep 1
				COUNTDOWN=$(( COUNTDOWN - 1 ))
			done
			if [ ! -z "$AUTOWAKEUP" ]; then ut "Auto-wakeup: $CHECKINTERVAL second(s) passed, removing loopsleep.txt"; rm loopsleep.txt; fi
		done
	fi
	ut "loopsleep.txt not detected, re-initializing loopsync"
}


lspush() # Data will be pushed from localhost to remote system
{
	rsync -avz $SOURCEFOLDER --progress --delete --log-file=./rsync.log -e "ssh -i $KEY -p $PORT" $REMOTEUSER@$RHOST:$TARGETFOLDER
}


lspull() # Data will be pulled from remote system to localhost
{
	rsync -avz --progress --delete --log-file=./rsync.log -e "ssh -i $KEY -p $PORT" $REMOTEUSER@$RHOST:$SOURCEFOLDER $TARGETFOLDER
}


globalcfg()
{
	if [ ! -f global.cfg ]; then
	ut "  Notice: Could not find $(pwd)/global.cfg."
	ut "          Using defaults:"
	ut "             Auto-wakeup will be disabled."
	ut "             Check-intervals between syncs will be set to 1800 seconds."; CHECKINTERVAL=1800
	ut "             Auto-sleep will be enabled"
	ut "             (loopsleep.txt is autogenerated after each cfg.lst traversal.)"
else 
	source global.cfg
	
	# Check interval
	if [ -z "$CHECKINTERVAL" ]; then ut "  Notice: \$CHECKINTERVAL was not set in global.cfg."; ut "          Check-intervals between syncs will be set to 1800 seconds."; CHECKINTERVAL=1800; fi
	
	# Check disable autosleep
	if [ -z "$DISABLEAUTOSLEEP" ]; then 
		ut "  Notice: \$DISABLEAUTOSLEEP was not set in global.cfg."
		ut "          Auto-sleep will be enabled (loopsleep.txt is generated after each cfg.lst traversal.)"
	else
		ut "  Auto-sleepmode will be disabled (loopsleep.txt will NOT be generated after each cfg.lst traversal.)"
	fi

	#check autowakeup
	if [ -z "$AUTOWAKEUP" ]; then
		ut "  Notice: \$AUTOWAKEUP was not set in global.cfg."
		ut "          Auto-wakeup will be disabled (loopsleep.txt will not be erased automatically)"
		if [ ! -z "$DISABLEAUTOSLEEP" ]; then ut "  Notice: Both auto-wakeup and auto-sleep is disabled"; ut "          This means loopsync will run continuously"; ut "          unless loopsleep.txt is generated manually/externally"; fi
	else
		ut "  Auto-wakeup will be enabled (loopsleep.txt will be erased $CHECKINTERVAL seconds after each cfg.lst traversal.)"
		if [ ! -z "$DISABLEAUTOSLEEP" ]; then ut "  Notice: Auto-wake up is enabled while auto-sleep is disabled"; ut "          This means loopsync will run continuously (without a $CHECKINTERVAL sec pause)"; ut "          unless loopsleep.txt is generated manually/externally"; fi
	fi
fi
}


looprep()
{
	ut
	status busy
	ut ""$YELLOW"loopsync init..."$DEF""
	ut 
	while read CURRENTDATASET <&9 # The script will repeat below until CTRL-C is pressed
		do
			status busy
			timeupdate
			ut "Preparing next rsync..."
			# Blank variables before we read CURRENTDATASET
			DESCRIPTION=
			PUSHPULL=
			TARGETSYSTEM=
			SOURCEFOLDER=
			TARGETFOLDER=
			KEY=
			PORT=
			MANUAL=

			ut "Reading sync configuration..."
			ut "     -> "$CYAN"$CURRENTDATASET"$DEF""

			if [ ! -f $CURRENTDATASET ]; then status error; ut "Could not find $CURRENTDATASET. Check your cfg.lst/config locations and try again"; exit; fi

			source $CURRENTDATASET
			if [ -z "$DESCRIPTION" ]; then status error; ut "DESCRIPTION not set, please check config!"; exit; fi
			if [ -z "$PUSHPULL" ]; then status error; ut "PUSHPULL not set, please check config!"; exit; fi
			if [ -z "$SOURCESYSTEM" ]; then status error; ut "SOURCESYSTEM not set, please check config!"; exit; fi
			if [ -z "$SOURCEFOLDER" ]; then status error; ut "SOURCEFOLDER not set, please check config!"; exit; fi
			if [ -z "$TARGETSYSTEM" ]; then status error; ut "TARGETSYSTEM not set, please check config!"; exit; fi
			if [ -z "$TARGETFOLDER" ]; then status error; ut "TARGETFOLDER not set, please check config!"; exit; fi
			if [ -z "$REMOTEUSER" ]; then status error; ut "REMOTEUSER not set, please check config!"; exit; fi				
			if [ -z "$KEY" ]; then status error; ut "KEY not set, please check config!"; exit; fi
			if [ -z "$PORT" ]; then status error; ut "PORT not set, please check config!"; exit; fi
			# Determine push or pull
			modeselect
			ut
			ut "Loaded config:"
			ut "   Description:                     "$CYAN"$DESCRIPTION"$DEF""
			ut
			ut "   Push or Pull?:                   "$CYAN"$PUSHPULL"$DEF""
			ut
			ut "   Source system:                   "$CYAN"$SOURCESYSTEM"$DEF""
			ut "   Source folder:                   "$CYAN"$SOURCEFOLDER"$DEF""
			ut
			ut "   Target system:                   "$CYAN"$TARGETSYSTEM"$DEF""
			ut "   Target folder:                   "$CYAN"$TARGETFOLDER"$DEF""
			ut
			ut "   Remote system to be accessed:    "$CYAN"$RHOST"$DEF""
			ut "   Remote user:                     "$CYAN"$REMOTEUSER"$DEF""
			ut "   Authentication key:              "$CYAN"$KEY"$DEF""
			ut "   Port used for SSH connection:    "$CYAN"$PORT"$DEF""
			ut
			ut "Looks like we're gonna $PUSHPULL changes from "$CYAN"$SOURCESYSTEM "$DEF"to "$CYAN"$TARGETSYSTEM"$DEF"."
			ut
			ut "Checking remote system:"
			CONCHECK="OK" #OK by default, checkping and checkssh will toggle this state upon error.
			checkping
			ut
			checkssh
			ut
			if [ "$CONCHECK" == "OK" ]; then
				ut "Connection checks "$GREEN"cleared"$DEF"!"
				ut
				sleep 1
				ut ""$YELLOW"BE ADVISED:"
				ut "ANY CHANGES PRESENT ON THE TARGET SYSTEM'S TARGET FOLDER,"
				ut "WILL BE ERASED IF NOT PRESENT IN SOURCE SYSTEM'S SOURCE FOLDER."
				ut
				ut "We'll now execute the following command:"
				if [ "$PUSHPULL" == "PUSH" ]; then
					ut ""$CYAN"rsync -avz $SOURCEFOLDER --progress --delete --log-file=./rsync.log -e \"ssh -i $KEY -p $PORT\" $REMOTEUSER@$RHOST:$TARGETFOLDER"
				else
					ut ""$CYAN"rsync -avz --progress --delete --log-file=./rsync.log -e \"ssh -i $KEY -p $PORT\" $REMOTEUSER@$RHOST:$SOURCEFOLDER $TARGETFOLDER"
				fi
				if [ -z "$MANUAL" ]; then
					ut "Sync will auto-start in 10 seconds."
					ut "PLEASE ABORT SCRIPT WITH "$LIGHTYELLOW"CTRL-C"$DEF" IF IN DOUBT!"
					sleep 7
				else
					ut "\$MANUAL variable detected"
					ut ""$GREEN"Press any key to start sync, or hold "$LIGHTYELLOW"CTRL-C"$DEF""$GREEN" to abort"$DEF""
					read -n 1 # This would not have worked without insight from these posts: http://stackoverflow.com/questions/6911520/read-command-in-bash-script-is-being-skipped
				fi
				status sync
				ut "Ready for rsync! - "$CYAN"3"
				sleep 1
				ut "Ready for rsync! - "$CYAN"2"
				sleep 1
				ut "Ready for rsync! - "$CYAN"1"
				sleep 1
				ut ""$PURPLE"#"$DEF" BEGIN RSYNC OUTPUT "$PURPLE"#"$PURPLE""
				if [ "$PUSHPULL" == "PUSH" ]; then
					lspush
				else
					lspull
				fi
				ut ""$PURPLE"#"$DEF" END RSYNC OUTPUT "$PURPLE"#"$DEF""
				ut
				ut "### Finished current dataset ($DESCRIPTION)"

			else
				ut "Connection checks "$RED"failed"$DEF"!"
				ut "Skipping this rsync session."
			fi
			status busy
			ut
			ut
	done 9< cfg.lst

	ut "Reached end of cfg.lst"

				if [ -z "$DISABLEAUTOSLEEP" ]; then
					ut "Looks like we are done for now, creating loopsleep.txt"
					echo "Done for now.">loopsleep.txt
				else
					ut "Looks like we are done for now."
				fi

	ut "##### Loopsync session finished!"
	status idle
	ut
}

# FUNCTIONS END:
##################


# The actual runscript:


#init
trap "{ status error; ut \"Caught SIGINT or SIGTERM. This happens if loopsync is aborted by Ctrl-C or otherwise killed.\";  exit; }" SIGINT SIGTERM # Set trap for catching Ctrl-C and kills, so we can reset terminal upon exit
trap "{	sleep 3; ut \"loopsync will now terminate.\"; sleep 2; logg \"loopsync $APPVERSION terminated at `date`\"; reset; echo \"loopsync $APPVERSION terminated at `date`\"; }" EXIT # exit procedure
#splashscreen
splash
sleep 2
clear

#tests
ut "Welcome to loopsync $APPVERSION."
ut
ut "# Applying config.."
globalcfg
sleep 3
ut "# Finished applying config."
ut
ut "Checking list over sync jobs.."
if [ ! -f cfg.lst ]; then status error; ut "Could not find $(pwd)/cfg.lst. Make sure this file exists and restart loopsync"; exit; fi
ut "        Sync list found!"

#main
while true
	do
		idlewait
		looprep
	done
status error
ut "loopsync halt"