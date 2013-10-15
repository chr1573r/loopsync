#!/bin/bash
# loopsync.sh - rsync replication script
# WARNING - This code is not necessarily safe on your system, use at your own responibility!
# Written by Christer Jonassen - cjdesigns.no
# Licensed under CC BY-NC-SA 3.0 (check LICENCE file or http://creativecommons.org/licenses/by-nc-sa/3.0/ for details.)
# Made possible by the wise *nix and BSD people sharing their knowledge online
#
# Check README for instructions

# Variables
APPVERSION="1.0"
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
		echo "$MCSTAMP [$CLEARTEXTSTATUS][$RHOST] $1">>lsyncsys.log
		echo "$MCSTAMP [$CLEARTEXTSTATUS][$RHOST] $1">>lsyncdebug.log
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
	echo -e "        "$GREEN"dP                                                                 "
	echo -e "        88                                                                 "
	echo -e "        88 .d8888b. .d8888b.  88d888b. .d8888b. dP    dP 88d888b. .d8888b. "
	echo -e "        88 88'  \`88 88'  \`88  88'  \`88 Y8ooooo. 88    88 88'  \`88 88'  \`"" "
	echo -e "        88 88.  .88 88.  .88  88.  .88       88 88.  .88 88    88 88.  ... "
	echo -e "        dP \`88888P' \`88888P'  88Y888P' \`88888P' \`8888P88 dP    dP \`88888P' "
	echo -e "        "$GRAY"ooooooooooooooooooooo~"$GREEN"88"$GRAY"~oooooooooooooooo~~~~"$GREEN".88"$GRAY"~ooooooooooooooooo"
	echo -e "        "$GREEN"                      dP                 d8888P    "$LIGHTBLACK"Cj Designs 2013"$DEF""
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
	ssh -n -i $KEY -p $PORT -q $RHOST exit
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
	if [ -f loopsleep.txt ]; then status idle; ut "Entering deep sleep (loopsleep.txt detected)"; fi
	
	COUNTDOWN=1800
	ut "Waiting until told otherwise. Re-checking for go-signal every "$LIGHTGRAY"$COUNTDOWN"$DEF" second(s)"
	while [ -f loopsleep.txt ]
	do
		until [ $COUNTDOWN == 0 ]; do
			sleep 1
			COUNTDOWN=$(( COUNTDOWN - 1 ))
		done
	done
	ut "loopsleep.txt not detected, re-initializing loopsync"
}


looprep()
{
	ut
	status busy
	ut ""$YELLOW"loopsync init..."$DEF""
	ut 
	while read CURRENTDATASET # The script will repeat below until CTRL-C is pressed
		do
			status busy
			timeupdate
			ut "Preparing next replication..."
			# Blank variables before we read CURRENTDATASET
			DESCRIPTION=
			RHOST=
			SOURCEFOLDER=
			TARGETFOLDER=
			KEY=
			PORT=

			ut "Reading configuration..."
			ut "     -> "$CYAN"$CURRENTDATASET"$DEF""
			source $CURRENTDATASET
			if [ -z "$DESCRIPTION" ]; then status error; ut "DESCRIPTION not set, please check config!"; ut "loopsync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$RHOST" ]; then status error; ut "RHOST not set, please check config!"; ut "loopsync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$SOURCEFOLDER" ]; then status error; ut "SOURCEFOLDER not set, please check config!"; ut "loopsync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$TARGETFOLDER" ]; then status error; ut "TARGETFOLDER not set, please check config!"; ut "loopsync.sh will now terminate."; sleep 2; exit; fi				
			if [ -z "$KEY" ]; then status error; ut "KEY not set, please check config!"; ut "loopsync.sh will now terminate."; sleep 2; exit; fi
			if [ -z "$PORT" ]; then status error; ut "PORT not set, please check config!"; ut "loopsync.sh will now terminate."; sleep 2; exit; fi

			ut
			ut "Loaded config:"
			ut "   Description:                  "$CYAN"$DESCRIPTION"$DEF""
			ut "   Target system:                "$CYAN"$RHOST"$DEF""
			ut "   Source folder:                "$CYAN"$SOURCEFOLDER"$DEF""
			ut "   Target folder:                "$CYAN"$TARGETFOLDER"$DEF""
			ut "   Authentication key:           "$CYAN"$KEY"$DEF""
			ut "   Port used for SSH connection: "$CYAN"$PORT"$DEF""
			ut
			ut "Looks like we're gonna push changes from "$CYAN"`hostname` "$DEF"to "$CYAN"$RHOST"$DEF"."
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
				ut "PLEASE ABORT SCRIPT WITH "$LIGHTYELLOW"CTRL-C "$DEF"IF IN DOUBT!"
				sleep 5
				ut "We'll now execute the following command:"
				ut "rsync -avz $SOURCEFOLDER --progress --delete --log-file=./rsync.log -e \"ssh -i $KEY -p $PORT\" $RHOST:$TARGETFOLDER"
				status sync
				ut "Ready for rsync replication! - "$CYAN"3"
				sleep 1
				ut "Ready for rsync replication! - "$CYAN"2"
				sleep 1
				ut "Ready for rsync replication! - "$CYAN"1"
				sleep 1
				ut ""$PURPLE"#"$DEF" BEGIN RSYNC OUTPUT "$PURPLE"#"$PURPLE""
				rsync -avz $SOURCEFOLDER --progress --delete --log-file=./rsync.log -e "ssh -i $KEY -p $PORT" $RHOST:$TARGETFOLDER
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
	done < cfg.lst

	ut "Looks like we are done for now, creating loopsleep.txt"
	echo "Done for now.">loopsleep.txt
	ut "##### Loopsync session finished!"
	status idle
	ut
}

# FUNCTIONS END:
##################


# The actual runscript:

trap "{ echo loopsync $APPVERSION terminated at `date`; exit; }" SIGINT SIGTERM EXIT # Set trap for catching Ctrl-C and kills, so we can reset terminal upon exit

splash
sleep 2
clear

while true
	do
		idlewait
		looprep
	done
status error
ut "loopsync halt"