#!/bin/bash
##!/bin/bash -x
##set -o xtrace

# this script rereads a text file which has fstab-like lines
# and tries to mount known filesystems if they aren't already mounted
# it also unmounts the filesystem if filesystem specific tests fail
# usage example for an entry in /etc/rc.local:
# /root/automounterd.sh -f /root/fstab >/tmp/automounterd.log 2>&1 &
#
# known filesystems are: cifs, smb, smbfs, sshfs, nfs, test (used for debugging)
# the filesystems are automatically unmounted if the remote hosts are not reachable or the share is not available
# any more e.g. via smbclient
# whats the advantage of this script?
# o) one can wake up your own storage server(s) e.g. via wake up on lan and then having this script run:
#    if the server is up - it gets automatically mounted
#    if the server shuts down - it gets automatically unmounted
# o) one can provide your own fstab file, which allowes on the fly modifications of mount parameters
#    between mount/umount cycles
#
# CHANGELOG:
#    2014-04-04 added parameter -r and -i
#               added flock usage on fstab files to provide a way of being sure the file isnt currently modified
#               added support for directories instead of single fstab file
#               added dummy test filesystem

usage()
{
cat << EOF
usage: $0 [-s SLEEPTIME] [-i] [-r] [-f FSTAB]

OPTIONS:
   -f      fstab file or a directory, DEFAULT=/etc/fstab
           if a directory is given its direct child files are assumed to be in fstab format
   -r      if a directory is given scan it recursively, otherwise this option is ignored
   -s      sleep time between fstab rescan in seconds, DEFAULT=60 seconds
           (only used if -i given or script has been started in background, e.g. using the ampersand character & on command line)
   -i      run in an endless loop
EOF
}

SLEEP=60
RECURSIVE=0
FILE="/etc/fstab"
DAEMONIZED=0
INFINITE=0
while getopts "f:s:ri" OPTION
do
     case $OPTION in
         s)
             SLEEP=$OPTARG
             if [[ ! $SLEEP =~ ^[0-9]+$ ]] ; then
                 echo "ERROR: Sleep not a number" >&2;
                 usage
                 exit 1
             fi
             if [ "$SLEEP" -le "0" ]; then
                 echo "ERROR: Sleep less or equal zero" >&2;
                 usage
                 exit 1
             fi
             ;;
         f)
             FILE=$OPTARG
             if [ -z $FILE ]; then
                echo "ERROR: no file given" >&2;
                usage
                exit 1
             fi
             ;;
         r)  RECURSIVE=1
             ;;
         i)  INFINITE=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [ -f $FILE ]
   then
     CMD="echo $FILE"
   elif [ -d $FILE ]
     then
        if [ "$RECURSIVE" -eq "0" ]
        then
            CMD="find $FILE -maxdepth 1 -type f"
        else
            CMD="find $FILE -type f"
        fi
   else
        echo "ERROR: $FILE doesnt exist";
        exit 255
fi

if [ "$INFINITE" -eq "1" ]; then
    DAEMONIZED=1
else
    DAEMONIZED=$(ps -o stat= -p $$)
    if [[ "$DAEMONIZED" != *"+"* ]]; then
        DAEMONIZED=1
    else
        DAEMONIZED=0
    fi
fi

while [ "$DAEMONIZED" -ge "0" ]; do

	while read fnam; do
	 (
       flock -x 9
       
       # if file has been deleted right after the lock has been acquired, ignore it
       if [ ! -e $fnam ]; then
           continue;
       fi

	   while read curline; do
	    # read seems to trim the lines already, so no need for a trim() function
	    if [[ ${#curline} == 0 || "${curline:0:1}" == "#" ]]
	    then
	        continue
	    fi
	
	    IFS=$'\040\t' read -ra ADDR <<< "$curline"
	    SRC=${ADDR[0]}
	    DST=${ADDR[1]}
	    TYPE=`echo ${ADDR[2]} | tr '[:upper:]' '[:lower:]'`
	    OPTS=${ADDR[3]}
	
	    MCNT=$(mount | grep " ${DST} " | grep -ci "${TYPE}")
	
	    SHALLMOUNT=0
	    SHALLUMOUNT=0
	
	    TMPTYPE=$TYPE
	    if [ $TMPTYPE == "fuse" ]; then
	        TMPTYPE=`echo "$SRC" | cut -d '#' -f1`
	    fi
	
	    case $TMPTYPE in
	    cifs | smb | smbfs)
	        # test if host is online
	        SCNT=$(smbclient -N -g -L "${SRC}" 2>/dev/null | grep -c -e "^Disk")
	        # if disk is not available AND mounted
	        if [ "$SCNT" -le "0" ] && [ "$MCNT" -gt "0" ]
	        then
	            SHALLUMOUNT=1
	        fi
	        # if dis available AND not mounted
	        if [ "$SCNT" -gt "0" ] && [ "$MCNT" -le "0" ]
	        then
	            SHALLMOUNT=1
	        fi
	        ;;
	    sshfs)
	        HOST=`echo "$SRC" | cut -d '@' -f2`
	        HOST=`echo "$HOST" | cut -d ':' -f1`
	        PCNT=$(ping -b -c 1 -W 2 -q "${HOST}" 2>&1 | grep -o -e '[0-9]* received' | grep -o -e '[0-9]*')
	        # if not available AND mounted
	        if [ "$PCNT" -le "0" ] && [ "$MCNT" -gt "0" ]
	        then
	            SHALLUMOUNT=1
	        fi
	        if [ "$PCNT" -gt "0" ] && [ "$MCNT" -le "0" ]
	        then
	            SHALLMOUNT=1
	        fi
	        ;;
	    nfs)
	        # test if host is online
	        POS=$(expr index "$SRC" :)
	        POS=$(($POS - 1))
	        if [[ "$POS" -le 0 ]]; then
	            continue
	        fi
	        HOST="${SRC:0:$POS}"
	        rpcinfo -t "${HOST}" nfs
	        RPCI=$?
	        # if not available AND mounted
	        if [ "$RPCI" -ne "0" ] && [ "$MCNT" -gt "0" ]
	        then
	            SHALLUMOUNT=1
	        fi
	        # if available AND not mounted
	        if [ "$RPCI" -eq "0" ] && [ "$MCNT" -le "0" ]
	        then
	            SHALLMOUNT=1
	        fi
	
	        ;;
	    "test")
	        echo "$curline"
	        ;;
	    *)
	        continue;
	        ;;
	    esac
	
	    # seems everything is up and ready - mount it
	    if [[ "$SHALLMOUNT" -eq "1" ]]; then
	        mount -t $TYPE -o $OPTS $SRC $DST
	    fi
	    if [[ "$SHALLUMOUNT" -eq "1" ]]; then
	        umount $DST
	    fi
	
	   done < $fnam

	  ) 9>>$fnam

	done < <($CMD)

	if [ "$DAEMONIZED" -eq "1" ]
	then
	    sleep $SLEEP
	else
	    DAEMONIZED=-1
	fi

done

