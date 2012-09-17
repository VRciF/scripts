#!/bin/bash

usage()
{
cat << EOF
usage: $0 [FSTAB] [OPTIONS]

OPTIONS:
   -d      Script is already running in daemonized mode, thus automounterd is running in an endless loop
   -f      fstab file, DEFAULT=/etc/fstab
   -s      sleep interval between fstab processing, only used if -d given
EOF
}

SLEEP=60
FILE=""
DAEMONIZED=2
while getopts "f:s:d" OPTION
do
     case $OPTION in
         s)
             SLEEP=$OPTARG
             ;;
         f)
             FILE=$OPTARG
             ;;
         d)
             DAEMONIZED=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [ "${#FILE}" -eq "0" ]
then
    FILE="/etc/fstab"
fi

if [ ! -f "$FILE" ]
then
    echo "ERROR: $FILE doesnt exist";
    exit 255
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

