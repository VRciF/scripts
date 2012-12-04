#!/bin/bash

LIMITKB=$((50 * 15)) # 30 kilobyte per minute * 15 minutes
STIME=$((15*60))  # sleep 15 minutes
#STIME=$((1*60))  # sleep 15 minutes

PREVINKB=-1
PREVOUTKB=-1

while [ true ]; do

#    CNTNONSMB=`netstat --numeric-hosts -t | grep -v ' 127.' | grep -Ev '192.168.0.20.:' | grep -v microsoft | tail -n +3`
    CNTNONSMB=`netstat -t --numeric-hosts | grep -Ev ':ssh[[:space:]]*[[:alpha:]]+' | grep -v microsoft | tail -n +3 | grep -c ''`

    INKBYTES=0
    OUTKBYTES=0

    while read -r LINE; do
        KBYTES=`echo $LINE | cut -d : -f 2 | sed 's/^ *//g' | cut -d \  -f 1 | sed 's/...$//'`
        INKBYTES=$(($INKBYTES + $KBYTES))

        KBYTES=`echo $LINE | cut -d : -f 2 | sed 's/^ *//g' | cut -d \  -f 9 | sed 's/...$//'`
        OUTKBYTES=$(($OUTKBYTES + $KBYTES))
    done < <(cat /proc/net/dev | grep -E 'eth|wlan')

    PREVKB=$(($PREVINKB + $PREVOUTKB))
    NOWKB=$(($INKBYTES + $OUTKBYTES))
    MAXKB=$(($PREVKB + $LIMITKB))
    if [ $CNTNONSMB -le "0" -a $PREVKB -gt "1" ]; then
        if [ $NOWKB -ge "$PREVKB" -a $NOWKB -le "$MAXKB" ]; then
            shutdown -h now
            break
        fi
    fi

    PREVINKB=$INKBYTES
    PREVOUTKB=$OUTKBYTES

    sleep $STIME
done
