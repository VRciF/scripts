#!/bin/bash

# the purpose of this script is to automatically shut down the host if
# network traffic drops below a given rate per minute AND no ssh connection is currently open

############# CONFIGURATION OPTIONS ###############
INTERVAL=15  # check interval
KBPERMIN=350  # kilobyte per minute
###################################################



LIMITKB=$(($KBPERMIN*$INTERVAL)) # kilobytes per interval
STIME=$(($INTERVAL*60)) # interval to seconds

PREVINKB=-1
PREVOUTKB=-1

while [ true ]; do

    CNTNONSMB=`netstat -p -t --numeric-hosts | grep -Ev ':ssh[[:space:]]*[[:alpha:]]+' | grep -v microsoft | grep -v rfs | tail -n +3 | grep -c ''`

    INKBYTES=0
    OUTKBYTES=0

    while read -r LINE; do
        KBYTES=`echo $LINE | cut -d : -f 2 | sed 's/^ *//g' | cut -d \  -f 1 | sed 's/...$//'`
        INKBYTES=$(($INKBYTES + $KBYTES))

        KBYTES=`echo $LINE | cut -d : -f 2 | sed 's/^ *//g' | cut -d \  -f 9 | sed 's/...$//'`
        OUTKBYTES=$(($OUTKBYTES + $KBYTES))
    done < <(cat /proc/net/dev | grep -v -E 'lo|Inter-|face')

    PREVKB=$(($PREVINKB + $PREVOUTKB))
    NOWKB=$(($INKBYTES + $OUTKBYTES))
    #MAXKB=$(($PREVKB + $LIMITKB))
    #if [ $CNTNONSMB -le "0" -a $PREVKB -gt "1" ]; then
    #    if [ $NOWKB -ge "$PREVKB" -a $NOWKB -le "$MAXKB" ]; then
    if [ $PREVINKB -gt 0 -a $PREVINKB -le $INKBYTES -a $PREVOUTKB -gt 0 -a $PREVOUTKB -le $OUTKBYTES ]; then
        DIFFINKB=$(($INKBYTES - $PREVINKB))
        DIFFOUTKB=$(($OUTKBYTES - $PREVOUTKB))
        DIFFKB=$(($DIFFINKB + $DIFFOUTKB))
        if [ $CNTNONSMB -le "0" -a $PREVKB -gt "1" -a $DIFFKB -le $LIMITKB -a $DIFFKB -ge 0 ]; then
            if [ -z "$(pidof rsync)" ]; then
                shutdown -h now
                break
            fi
        fi
    fi

    PREVINKB=$INKBYTES
    PREVOUTKB=$OUTKBYTES

    sleep $STIME
done
