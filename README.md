loopsync v.2 - README v.1.1
=========================
http://csdnserver.com - http://github.com/chr1573r/loopsync

Written by Christer Jonassen - Cj Designs

loopsync is licensed under CC BY-NC-SA 3.0.

(check LICENCE file or http://creativecommons.org/licenses/by-nc-sa/3.0/ for details.)

What is loopsync?
---------------------

![loopsync](https://raw.githubusercontent.com/chr1573r/chr1573r.github.io/master/repo-assets/loopsync/img/loopsync.png)

loopsync is a bash script based rsync wrapper that aims to automate different file sync scenarios.
While loopsync v.1 was push only (transfer from local system to remote system),
version 2 supports push (transfer from remote system to local system) and is overall more versatile.

BE CAREFUL! By default loopsync deletes files/directories in target folder if they don't exist in the source folder

You can set up as many sync configurations that you like and loopsync will traverse through them sequently.
This process is repeated (hence the "loop" in loopsync) and can be controlled by loopsync's timer and/or external scripts etc.
By default, the script is meant to be always running while a cronjob can trigger the sync loop.

loopsync can be used to backup multiple clients to a server, replicating files from one server to another etc.


Install instructions
----------------------

Notice!: These steps might not be right/harmful for your setup, 
please take the time necessary to make sure loopsync.sh is set up correctly.
Sample config are included to illustrate a typical usage


Providing that you have downloaded and unzipped loopsync on your computer:

### 1. Set desired options in global.cfg
This is step is required if you want to override the default mode of operation

### 2. Create sync configs
Each sync config has its own file which needs to be set up.
Check the sample files and review the rest of the readme file for more details
Add the path of the sync files to cfg.lst
You should test new syncs in a test environment, so you won't

### 3. Set up a cronjob to trigger syncs
Again, this may not be necessary depending on you setup.
By default, loopsync will not repeat the sync process
until a file named loopsleep.txt is removed.
With cron you can easily delete this file at the desired time/interval

### 3. Permit and execute
Give loopsync.sh permission to run by executing the following command:
`chmod +x loopsync.sh`

That's pretty much it! You can now start loopsync by executing the following:
`./loopsync.sh`


How does it work?
-----------------

loopsync is basically an automated rsync launcher.

loopsync/rsync is set to _DELETE_ target files/folders if they don't match the source files/folders.
Keep this in mind!

When started, it parses and applies any options set in global.cfg.
It grabs the first sync config from cfg.lst, determines push/pull and initiates connection checks (ping and ssh)
After connections checks clears, it will initiate rsync over ssh with the remote machine.
When the rsync is finished, it grabs the next line from cfg.lst and repeats until it reaches the end.
loopsync enters a sleepmode by default after syncing with all the hosts, controlled by the precence of a file named "loopsleep.txt".
By default, loopsync would not sync again until that file is erased by a cronjob or externally.
You change this behavior by enabling auto-wakeup in global.cfg. This enables loopsync.sh to delete loopsleep.txt automatically
after a set number of seconds.

loopsync continues to run until interrupted by `Ctrl-C` or killed otherwise. 
 

Technical details:
------------------

Written in bash.

Besides bash, you'll need ssh(d) and rsync and the following common binaries:
`ping`, `uptime`, `date`, `sleep`, `read`.
Should run on the most common Linux distros, 
tested in development on raspian, ClearOS 5 and FreeNAS 8.


Troubleshooting/Tips and tricks:
--------------------------------

Read the man page and/or check tutorials for rsync. You need to know basic rsync
inorder to use loopsync in a safe and useful manner

Beware that trailing forward-slashes `/` on the path set in $SOURCEFOLDER
greatly affects whether a folder(and its contents) or just its contents is syncronized.
Rule of thumb is that `/` means "Copy the contents of this directory"

Use the $MANUAL variable in sync configs when you first test them,
this allows you to manually start the sync.

You probably need to have a working ssh keybased login in place between your systems,
otherwise loopsync won't be very automatic at all.

If the last config in cfg.lst are skipped, and/or loopsync crashes,
check if you need to add/remove a linebreak at the end of cfg.lst.
It might not read the last line if there is no linebreak.

Use GNU screen or tmux to run loopsync. This way you can easily run loopsync in the
background, while being able to view it later.

Experiment with the different options in global.cfg to see what works best on your setup

global.cfg and sync configs are read using `source`, so you can easily inject your own
stuff in them if you want to

