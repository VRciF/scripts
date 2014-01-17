#!/bin/bash

# this script rereads a text file which has fstab-like lines
# and tries to mount known filesystems if they aren't already mounted
# it also unmounts the filesystem if filesystem specific tests fail
# usage example for an entry in /etc/rc.local:
# /root/automounterd.sh -f /root/fstab >/tmp/automounterd.log 2>&1 &
#
# known filesystems are: cifs, smb, smbfs, sshfs, nfs
# the filesystems are automatically unmounted if the remote hosts are not reachable or the share is not available
# any more e.g. via smbclient
# whats the advantage of this script?
# o) having this script run, one can wake up your own storage via wake up on lan
#    if the storage is up - it gets automatically mounted
#    if the storage shuts down - it gets automatically unmounted
# o) one can provide your own fstab file, which allowes on the fly modifications of mount parameters
#    between mount/umount cycles

usage()
{
cat << EOF
usage: $0 [FSTAB] [OPTIONS]

OPTIONS:
   -f      fstab file, DEFAULT=/etc/fstab
EOF
}

SLEEP=60
FILE="/etc/fstab"
DAEMONIZED=2
while getopts "f:s:" OPTION
do
     case $OPTION in
         s)
             SLEEP=$OPTARG
             ;;
         f)
             FILE=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [ ! -f "$FILE" ]
then
    echo "ERROR: $FILE doesnt exist";
    exit 255
fi
DAEMONIZED=$(ps -o stat= -p $$)
if [[ "$DAEMONIZED" != *"+"* ]]; then
    DAEMONIZED=1
fi

while [ "$DAEMONIZED" -gt "0" ]; do

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
done < $FILE

if [ "$DAEMONIZED" -eq "2" ]
then
    DAEMONIZED=0
else
    sleep $SLEEP
fi

done

