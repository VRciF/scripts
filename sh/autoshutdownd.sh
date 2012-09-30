#!/bin/bash

LIMITKB=$((75 * 60 *15)) # 75 kilobyte per second * 15 minutes
#STIME=$((15*60))  # sleep 15 minutes
STIME=$((15*60))  # sleep 15 minutes

PREVINKB=-1
PREVOUTKB=-1

while [ true ]; do

    CNTNONSMB=`netstat --numeric-hosts -t | grep -v ' 127.' | grep -v microsoft | tail -n +3 | grep -c ""`

    INKBYTES=0
    OUTKBYTES=0

    while read -r LINE; do
        KBYTES=`echo $LINE | cut -d \  -f 2`
        KBYTES=$(($KBYTES / 1024))
        INKBYTES=$(($INKBYTES + $KBYTES))

        KBYTES=`echo $LINE | cut -d \  -f 10`
        KBYTES=$(($KBYTES / 1024))
        OUTKBYTES=$(($OUTKBYTES + $KBYTES))
    done < <(cat /proc/net/dev | grep -E 'eth|wlan')

    if [ $CNTNONSMB -le "0" -a $PREVINKB -ne "-1" -a $PREVOUTKB -ne "-1" ]; then
        DIFF=$(($INKBYTES - $PREVINKB))
        DIFF=$(($DIFF + ($OUTKBYTES - $PREVOUTKB)))
        echo "diff: $DIFF vs $LIMITKB"
        if [ "$DIFF" -lt "$LIMITKB" ]; then
            shutdown -h now
            break
        fi
    fi
    PREVINKB=$INKBYTES
    PREVOUTKB=$OUTKBYTES

    sleep $STIME
done

