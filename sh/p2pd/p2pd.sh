#!/bin/bash

#MISSING: o) run script if new peer becomes available
#         o) run script if new service becomes available
#         o) run script if peer gets removed
#         CLIENT script to call a remote service by UUID or NAME 

command -v socat >/dev/null 2>&1 || { echo >&2 "I require 'socat' but it's not installed.  Aborting."; exit 1; }

START=$(date +%s)

UUID=$(cat /proc/sys/kernel/random/uuid)

#set -x

# directory where client executable scripts reside
${PEERDIR:=""}

# main host which, on the first run, is needed to set everything up, can be a multicast or broadcast ip for local network usage 
INITNODE=""
# name of the current p2pd process - this one is used to identify the host which makes it easier to send messages to destinations without knowing their exact ip:port
# cause the ip:port is hidden by the NAME in the network
NAME=""

# array of nodes
declare -a NODES
# monkey port 0xAFFE = 45054
PORT=45054

function show_help {
    >&2 echo "$0 [-h/-?] [-i HOST:PORT] [-n NAME] [-l [IP:]PORT] -e PEERDIR [-b HEARTBEATINTERVAL] [-s PEERS|HEARTBEAT|SERVICES]"
    >&2 echo "Options are:"
    >&2 echo "-h/-?                   this help page"
    >&2 echo "-i HOST:PORT            the initial host and port used for heartbeat notifications, used to initialize the p2p network"
    >&2 echo "-n NAME the             name of the current p2pd instance used to identify host(s)"
    >&2 echo "-l [IP:]PORT            the port where to listen for heartbeat packets from peers, if IP is given the corresponding interface will be used"
    >&2 echo "-e PEERDIR              mandatory, used to save current/initial configuration and where the services (executables) can be found"
    >&2 echo "-b HEARTBEATINTERVAL    interval in seconds to notify peers about the daemon being still alive, default 300"
}

SHOW=""
HEARTBEATINTERVAL=300

INCOMINGPACKET=0

while getopts "h?i:n:l:e:b:s:x" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    i)  INITNODE="$OPTARG"
        ;;
    n)  NAME="$OPTARG"
        ;;
    l)  PORT="$OPTARG"
        ;;
    e)  PEERDIR="$OPTARG"
        ;;
    b)  HEARTBEATINTERVAL="$OPTARG"
        ;;
    s)  SHOW="$OPTARG"
        ;;
    x)  INCOMINGPACKET=1
        ;;
    esac
done

if [ ! -d "$PEERDIR" ]; then
    >&2 echo "ERROR: given peerdirectory '$PEERDIR' not a directory"
    show_help
    exit 1
fi
if [ -f "$PEERDIR/.p2pd.cfg" ]; then
    exec 3<>$PEERDIR/.p2pd.cfg

    read TMP <&3
    if [ "${#NAME}" -eq "0" ]; then
        NAME=$TMP
    fi

    read UUID <&3

    read TMP <&3
    if [ "${#PORT}" -eq "0" ]; then
        PORT=$TMP
    fi
    read TMP <&3
    if [ "${#INITNODE}" -eq "0" ]; then
        INITNODE=$TMP
    fi
    read TMP <&3
    if [ "${#HEARTBEATINTERVAL}" -eq "0" ]; then
        HEARTBEATINTERVAL=$TMP
    fi
fi

if [ "$INCOMINGPACKET" -eq "1" ]; then
    read LINE
    PREVIFS="$IFS"
    IFS=':' read -a parts <<< "$LINE"
    IFS="$PREVIFS"
    cnt=${#parts[@]}

    NAMESPACE=""
    COMMAND=${parts[0]}
    unset parts[0]
    if [ "$cnt" -ne "1" ]; then
        NAMESPACE=$(printf ":%s" "${parts[@]}")
        NAMESPACE=${NAMESPACE:1}
        unset parts
    fi

    case "$COMMAND" in
        "HB")

            IFS=':' read PEERUUID PEERNAME PEERPORT <<< "$NAMESPACE"

            touch $PEERDIR/.peers
            (
                flock -x 200

                # remove current heartbeat peer
                grep -v "$PEERUUID:$PEERNAME:$SOCAT_PEERADDR:$PEERPORT" $PEERDIR/.peers > $PEERDIR/.peers.tmp
                mv $PEERDIR/.peers.tmp $PEERDIR/.peers

                cat - > $PEERDIR/.heartbeat.$PEERUUID

                # add heartbeat to peers
                echo "$PEERUUID:$PEERNAME:$SOCAT_PEERADDR:$PEERPORT" >> $PEERDIR/.peers
                sort -u -o $PEERDIR/.peers $PEERDIR/.peers
            ) 200<$PEERDIR/.peers
            ;;
        "PEERS")
            touch $PEERDIR/.peers
            (
                flock -x 200

                while read LINE || [ -n "$LINE" ]; do
                    echo "$LINE" >> $PEERDIR/.peers
                done

                sort -u -o $PEERDIR/.peers $PEERDIR/.peers
            ) 200<$PEERDIR/.peers
            ;;
        "SERVICES")
            PEERUUID=$NAMESPACE
            if [ "$UUID" != "$PEERDIR" ]; then
	            touch $PEERDIR/.services
	            (
	                flock -x 200
	
	                while read SERVICE || [ -n "$SERVICE" ]; do
	                    echo "$PEERUUID:$SERVICE" >> $PEERDIR/.services
	                done
	
	                sort -u -o $PEERDIR/.services $PEERDIR/.services
	            ) 200<$PEERDIR/.services
            fi
            ;;
        "EXEC")
            RELATIVE=$(realpath -s "/$NAMESPACE")
            if [ -x "$PEERDIR/$RELATIVE.sh" ]; then
                RELATIVE="$RELATIVE.sh"
            fi
            if [ -x "$PEERDIR/$RELATIVE" ]; then
                exec $PEERDIR/$RELATIVE <&0
            fi
            ;;
    esac

    touch $PEERDIR/.peers
    (
        flock -x 200

        # remove peers whose heartbeat is older than 1 day
        echo "" > $PEERDIR/.peers.tmp

        HBLIMIT=$((START-86400))
        while read LINE || [ -n "$LINE" ]; do
            if [ "${#LINE}" -eq 0 ]; then
                continue
            fi

            IFS=':' read PEERUUID REST <<< "$LINE"
            TIMESTAMP=0
            if [ -f $PEERDIR/.heartbeat.$PEERUUID ]; then
                TIMESTAMP=$(stat -c %Y $PEERDIR/.heartbeat.$PEERUUID)
            fi

            if [[ "$TIMESTAMP" -gt "$HBLIMIT" && "$UUID" != "$PEERDIR" ]]; then
                echo "$LINE" >> $PEERDIR/.peers.tmp
            else
                rm -f $PEERDIR/.heartbeat.$PEERUUID

                grep -v "$PEERUUID:" $PEERDIR/.services > $PEERDIR/.services.tmp
                mv $PEERDIR/.services.tmp $PEERDIR/.services
            fi
        done <$PEERDIR/.peers
        mv $PEERDIR/.peers.tmp $PEERDIR/.peers
    ) 200<$PEERDIR/.peers

    exit 0;
fi


# if show command is given
case "$SHOW" in
    "PEERS")
        cat $PEERDIR/.peers
        exit 0
        ;;
    "HEARTBEAT")
        cat $PEERDIR/.heartbeat.*
        exit 0
        ;;
    "SERVICES")
        cat $PEERDIR/.services
        exit 0
        ;;
esac

if ! [[ $HEARTBEATINTERVAL =~ ^[0-9]+$ ]] ; then
    >&2 echo "ERROR: HeartbeatInterval '$HEARTBEATINTERVAL' not a number"
    show_help
    exit 2
fi
if [[ $HEARTBEATINTERVAL -le 0 ]] ; then
    >&2 echo "ERROR: HeartbeatInterval '$HEARTBEATINTERVAL' not a positive number"
    show_help
    exit 2
fi

echo "$$" > $PEERDIR/.pid

# save current command line configuration
echo "$NAME" > $PEERDIR/.p2pd.cfg
echo "$UUID" >> $PEERDIR/.p2pd.cfg
echo "$PORT" >> $PEERDIR/.p2pd.cfg
echo "$INITNODE" >> $PEERDIR/.p2pd.cfg
echo "$HEARTBEATINTERVAL" >> $PEERDIR/.p2pd.cfg

function send_to_peers(){
    PACKET=$1
    PEER=$2

    if [ "${#PEER}" -eq 0 ]; then
        PEER="0.0.0.0:0"
    else
        echo -n -e "$PACKET" | socat STDIO "UDP-DATAGRAM:$PEER"
    fi

    touch $PEERDIR/.peers
    (
        flock -s 200
        while read LINE  || [ -n "$LINE" ]; do
            if [ "${#LINE}" -eq 0 ]; then
                continue;
            fi

            PREVIFS=$IFS
            IFS=':' read PEERUUID PEERNAME PEERADDR PEERPORT <<< "$LINE"
            IFS=$PREVIFS

            # notify peer
            echo -n -e "$PACKET" | socat STDIO "UDP-DATAGRAM:$PEERADDR:$PEERPORT"
        done < <(grep -v "$PEER" $PEERDIR/.peers)
    ) 200<$PEERDIR/.peers
}

function heartbeat_task(){
    NAME=$1
    PEERDIR=$2
    PORT=$3
    HEARTBEATINTERVAL=$4
    INITNODE=$5
    START=$6

    while [ $(ps -p ${pid:-$$} -o ppid=) -ne 1 ]; do
                    read P2PUPTIME
            read HOSTUPTIME
            read HOSTIDLETIME

	    # send peer notification
        NOW=$(date +%s)
        PREVIFS=$IFS
        IFS=' ' read UPTIME IDLETIME </proc/uptime
        IFS=$PREVIFS

        DIFF=$(($NOW-$START))

        PACKET=""
        while read LINE || [ -n "$LINE" ]; do
            PLEN=${#PACKET}
            LLEN=${#LINE}
            # if packet size is greater than mtu
            if [ $(($PLEN+$LLEN+1)) -ge 1500 ]; then
                send_to_peers "$PACKET" "$INITNODE"
                PACKET=""
            fi

            if [ "${#PACKET}" -eq "0" ]; then
                PACKET="HB:$UUID:$NAME:$PORT\n$DIFF\n$UPTIME\n$IDLETIME"
            fi

            PACKET="$PACKET\n$LINE"
        done < <(cat /proc/net/dev | tail -n -2 | grep -v lo:)
        if [ "${#PACKET}" -ne "0" ]; then
            send_to_peers "$PACKET" "$INITNODE"
        fi

        #PACKET="HB:$UUID:$NAME:$PORT\n$DIFF\n$UPTIME\n$IDLETIME\n$NETSTATS"
        #send_to_peers "$PACKET" "$INITNODE"

        # notify every known peer about local services and known remote peers
        PACKET=""

        while read LINE || [ -n "$LINE" ]; do
            if [ "${#LINE}" -eq "0" ]; then
                continue
            fi

            PREVIFS=$IFS
            IFS=':' read PEERUUID PEERNAME PEERADDR PEERPORT <<< "$LINE"
            IFS=$PREVIFS

            PEER="$PEERUUID:$PEERNAME:$PEERADDR:$PEERPORT"

            PLEN=${#PACKET}
            PEERLEN=${#PEER}
            # if packet size is greater than mtu
            if [ $(($PLEN+$PEERLEN+1)) -ge 1500 ]; then
                send_to_peers "$PACKET" "$INITNODE"
                PACKET=""
            fi

            if [ "${#PACKET}" -eq "0" ]; then
                PACKET="PEERS"
            fi

            PACKET="$PACKET\n$PEER"
        done < $PEERDIR/.peers
        if [ "${#PACKET}" -ne "0" ]; then
            send_to_peers "$PACKET" "$INITNODE"
        fi

	    # notify every known peer about local services and known remote peers
	    PACKET=""
	    while read LINE || [ -n "$LINE" ]; do
		    SERVICE=${LINE#$PEERDIR}

            PLEN=${#PACKET}
            SLEN=${#SERVICE}
            # if packet size is greater than mtu
            if [ $(($PLEN+$SLEN+1)) -ge 1500 ]; then
                send_to_peers "$PACKET" "$INITNODE"
                PACKET=""
            fi

            if [ "${#PACKET}" -eq "0" ]; then
                PACKET="SERVICES:$UUID"
            fi

	        PACKET="$PACKET\n$SERVICE"
		done < <(find $PEERDIR -type f -executable 2>/dev/null)
		if [ "${#PACKET}" -ne "0" ]; then
            send_to_peers "$PACKET" "$INITNODE"
        fi

        inotifywait -e close_write -e attrib --exclude '\.(heartbeat|peers|services|p2pd).*' -r -q -t $HEARTBEATINTERVAL $PEERDIR
    done
}

PREVIFS=$IFS
IFS=':' read -a parts <<< "$PORT"
IFS=$PREVIFS

cnt=${#parts[@]}
PORT=${parts[$(($cnt-1))]}
unset parts[$(($cnt-1))]
HOST=$(printf ":%s" "${parts[@]}")
HOST=${HOST:1}
unset parts


heartbeat_task "$NAME" "$PEERDIR" $PORT $HEARTBEATINTERVAL "$INITNODE" $START &
HEARTBEAT_PID=$!

ARG="UDP-RECVFROM:$PORT"

if [ "${#HOST}" -ne "0" ]; then
    ARG="UDP-RECVFROM:$PORT,ip-add-membership=$HOST"
fi

socat $ARG,setsockopt-int=1:2:1,fork EXEC:"$0 -x -e '$PEERDIR'"
#socat $ARG,setsockopt-int=1:2:1,fork EXEC:"echo DATA"

kill $HEARTBEAT_PID >/dev/null 2>&1

echo "" > $PEERDIR/.pid
