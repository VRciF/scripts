#!/bin/bash

# MISSING: CLIENT script to call a remote service by UUID or NAME 

function parse_network_packet() {
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
            PREVIFS="$IFS"
            IFS=':' read PEERUUID PEERNAME PEERPORT <<< "$NAMESPACE"
            IFS=$PREVIFS

            touch $PEERDIR/.peers
            (
                flock -x 200

                PCNT=$(grep -c "$PEERUUID:$PEERNAME:$SOCAT_PEERADDR:$PEERPORT" $PEERDIR/.peers)
                if [ "$PCNT" -eq "0" ]; then
                    export PEERUUID=$PEERUUID
                    export PEERNAME=$PEERNAME
                    export PEERADDR=$SOCAT_PEERADDR
                    export PEERPORT=$PEERPORT
                    export P2P_TASK="peer-up"

                    # call "new-peer" script'
                    while read SCRIPT; do
                        SCRIPT="$PEERDIR/p-mod.d/$SCRIPT"
                        if [ -x "$SCRIPT" ]; then
                            exec $SCRIPT >/dev/null 2>&1
                        fi
                    done < <(ls -1 $PEERDIR/p-mod.d 2>/dev/null)
                fi

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

	                PCNT=$(grep -c "$PEERUUID:$SERVICE" $PEERDIR/.services)
	                if [ "$PCNT" -eq "0" ]; then
	                    export PEERUUID=$PEERUUID
	                    export PEERSERVICE=$SERVICE
	                    export PEERADDR=$SOCAT_PEERADDR
	                    export P2P_TASK="service-up"

	                    # call "service up" script
	                    while read SCRIPT; do
	                        SCRIPT="$PEERDIR/p-mod.d/$SCRIPT"
	                        if [ -x "$SCRIPT" ]; then
	                            exec $SCRIPT >/dev/null 2>&1
	                        fi
	                    done < <(ls -1 $PEERDIR/p-mod.d 2>/dev/null)
	                fi

                    while read SERVICE || [ -n "$SERVICE" ]; do
                        echo "$PEERUUID:$SERVICE" >> $PEERDIR/.services
                    done
    
                    sort -u -o $PEERDIR/.services $PEERDIR/.services
                ) 200<$PEERDIR/.services
            fi
            ;;
        "EXEC")
            PREVIFS="$IFS"
            IFS=':' read TRANSACTIONO PARTNO EXECPATH <<< "$NAMESPACE"
            IFS='/' read -a parts <<< "/$EXECPATH"
            IFS=$PREVIFS

            # remove relative parts of path
            for i in "${!parts[@]}"
            do
                if [ "${parts[$i]}" == "" ]; then
                    unset parts[$i]
                elif [ "${parts[$i]}" == "." ]; then
                    unset parts[$i]
                elif [ "${parts[$i]}" == ".." ]; then
                    unset parts[$i]
                    if [ "$i" -gt 0 ]; then
                        unset parts[$(($i-1))]
                    fi
                fi
            done

            if [ -x "$PEERDIR/$RELATIVE.sh" ]; then
                RELATIVE="$RELATIVE.sh"
            fi

            if [ -x "$PEERDIR/$RELATIVE" ]; then
                export P2PD_TID="$TRANSACTIONO"
                export P2PD_PNO="$PARTNO"
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

            PREVIFS="$IFS"
            IFS=':' read PEERUUID PEERNAME PEERADDR PEERPORT <<< "$LINE"
            IFS=$PREVIFS

            TIMESTAMP=0
            if [ -f $PEERDIR/.heartbeat.$PEERUUID ]; then
                TIMESTAMP=$(stat -c %Y $PEERDIR/.heartbeat.$PEERUUID)
            fi

            if [[ "$TIMESTAMP" -gt "$HBLIMIT" && "$UUID" != "$PEERDIR" ]]; then
                echo "$LINE" >> $PEERDIR/.peers.tmp
            else
                rm -f $PEERDIR/.heartbeat.$PEERUUID

                export PEERUUID=$PEERUUID
                export PEERNAME=$PEERNAME
                export PEERADDR=$SOCAT_PEERADDR
                export PEERPORT=$PEERPORT

                SCNT=0
                while read SLINE; do
                    PREVIFS="$IFS"
                    IFS=':' read PEERUUID SERVICE <<< "$LINE"
                    IFS=$PREVIFS

                    export SERVICE_$SCNT="$SERVICE"
                    SCNT=$(($SCNT+1))
                done < <(grep "$PEERUUID:" $PEERDIR/.services)

                # call "remove-peer" script'
                export P2P_TASK="peer-down"
                while read SCRIPT; do
                    SCRIPT="$PEERDIR/p-mod.d/$SCRIPT"
                    if [ -x "$SCRIPT" ]; then
                        exec $SCRIPT >/dev/null 2>&1
                    fi
                done < <(ls -1 $PEERDIR/p-mod.d 2>/dev/null)

                grep -v "$PEERUUID:" $PEERDIR/.services > $PEERDIR/.services.tmp
                mv $PEERDIR/.services.tmp $PEERDIR/.services
            fi
        done <$PEERDIR/.peers
        mv $PEERDIR/.peers.tmp $PEERDIR/.peers
    ) 200<$PEERDIR/.peers

    exit 0;
}
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

        PACKET="HB:$UUID:$NAME:$PORT\n$DIFF\n$UPTIME\n$IDLETIME\n$NETSTATS"
        send_to_peers "$PACKET" "$INITNODE"

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

        inotifywait -e close_write -e attrib --exclude '\.(heartbeat|peers|services|p2pd|p-mod.d).*' -r -q -t $HEARTBEATINTERVAL $PEERDIR
    done
}

function call_service() {
    PEERDIR=$1
    SERVICENAME=$2
    DESTINATIONHOSTS=$3

    PREVIFS=$IFS
    IFS=':' read -a parts <<< "$DESTINATIONHOSTS"
    IFS=$PREVIFS

    REGEX=$(printf "\\|%s" "${parts[@]}")
    REGEX=${REGEX:1}

    grep -e 'URL\|Get' examples.desktop

    TID=$(cat /proc/sys/kernel/random/uuid)
    CNT=0

    MAXPLEN=1500
    while [ true ]; do
        PACKET="EXEC:$TID:$CNT:$SERVICENAME\n"
        MAXPAYLOADLEN=$(($MAXPLEN-${#PACKET}))
        PAYLOAD=$(head -c $MAXPAYLOADLEN)
        
        if [ "${#PAYLOAD}" -eq "0" ];then
            break
        fi

        PACKET="$PACKET$PAYLOAD"
        while read LINE; do
              PREVIFS=$IFS
              IFS=':' read -a PEERUUID PEERNAME PEERADDR PEERPORT <<< "$LINE"
              IFS=$PREVIFS

              echo -n "$PACKET" | socat STDIO "UDP-DATAGRAM:$PEERADDR:$PEERPORT"
        done < <(grep -e '$REGEX' $PEERDIR/.peers)
    done
}

function show_current_stats(){
    SHOW=$1

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
}


function show_help() {
    >&2 echo "$0 [-h/-?] -d PEERDIR [-i HOST:PORT] [-n NAME] [-l [IP:]PORT] [-b HEARTBEATINTERVAL] [-s PEERS|HEARTBEAT|SERVICES] [-e SERVICENAME] [-g [UUID][:NAME][:...]]"
    >&2 echo "Options are:"
    >&2 echo "-h/-?                   this help page"
    >&2 echo "-i HOST:PORT            the initial host and port used for heartbeat notifications, used to initialize the p2p network"
    >&2 echo "-n NAME the             name of the current p2pd instance used to identify host(s)"
    >&2 echo "-l [IP:]PORT            the port where to listen for heartbeat packets from peers, if IP is given the corresponding interface will be used"
    >&2 echo "-d PEERDIR              mandatory, used to save current/initial configuration and where the services (executables) can be found"
    >&2 echo "-b HEARTBEATINTERVAL    interval in seconds to notify peers about the daemon being still alive, default 300"
    >&2 echo "-s PEERS|HEARTBEAT|SERVICES    show the current stats for know peers, heartbeat or services"
    >&2 echo "-e SERVICENAME          call the given service"
    >&2 echo "-g UUID:NAME    show the current stats for know peers, heartbeat or services"
}

command -v socat >/dev/null 2>&1 || { echo >&2 "ERROR: I require 'socat' but it's not installed.  Aborting."; exit 1; }

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
MTU=0

SHOW=""
HEARTBEATINTERVAL=300

INCOMINGPACKET=0

EXECUTESERVICE=""
EXECUTEDESTINATION=""

# load options from config file
if [ -f "$PEERDIR/.p2pd.cfg" ]; then
    source "$PEERDIR/.p2pd.cfg"
fi

# save command line options
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
    d)  PEERDIR="$OPTARG"
        ;;
    b)  HEARTBEATINTERVAL="$OPTARG"
        ;;
    s)  SHOW="$OPTARG"
        ;;
    x)  INCOMINGPACKET=1
        ;;
    e)  EXECUTESERVICE="$OPTARG"
        ;;
    g)  EXECUTEDESTINATION="$OPTARG"
        ;;
    esac
done

# validate command line options
if [ ! -d "$PEERDIR" ]; then
    >&2 echo "ERROR: given peerdirectory '$PEERDIR' not a directory"
    show_help
    exit 1
fi
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

# if it's about parsing an incoming network data packet
if [ "$INCOMINGPACKET" -eq "1" ]; then
    parse_network_packet
    exit 0
fi

# if show command is given
if [ "${#SHOW}" -ne "0" ]; then
    show_current_stats "$SHOW"
fi

# if a peer's service shall be called
if [ "${#EXECUTESERVICE}" -ne "0" ]; then
    call_service "$PEERDIR" "$EXECUTESERVICE" "$EXECUTEDESTINATION"
    exit 0
fi

# save current daemon pid
echo "$$" > $PEERDIR/.pid

# determine maximum transmission unit
if [ "$MTU" -eq "0" ]; then
    command -v ping >/dev/null 2>&1 || MTU=1500
fi

if [ "$MTU" -eq "0" ]; then
	PKT_SIZE=1473
	HOSTNAME="8.8.8.8"

	count=1
	while [ $count -eq 1 ]; do
	 ((PKT_SIZE--))
	 count=$((`ping -M do -c 1 -s $PKT_SIZE $HOSTNAME | grep -c "Frag needed"`))
	done

	MTU=$((PKT_SIZE + 28))
fi

# save current command line configuration
echo "NAME=$NAME" > $PEERDIR/.p2pd.cfg
echo "UUID=$UUID" >> $PEERDIR/.p2pd.cfg
echo "PORT=$PORT" >> $PEERDIR/.p2pd.cfg
echo "INITNODE$INITNODE" >> $PEERDIR/.p2pd.cfg
echo "HEARTBEATINTERVAL=$HEARTBEATINTERVAL" >> $PEERDIR/.p2pd.cfg
echo "MTU=$MTU" >> $PEERDIR/.p2pd.cfg

# parse given listen PORT for host part
# if a host is given it is used as multicast address
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
	if [[ $HOST =~ ^(ff|2(2[4-9]|3[0-9])) ]]; then
	    ARG="UDP-RECVFROM:$PORT,ip-add-membership=$HOST"
	else
	    ARG="UDP-RECVFROM:$PORT,bind=$HOST"
	fi
fi

socat $ARG,setsockopt-int=1:2:1,fork EXEC:"$0 -x -e '$PEERDIR'"
#socat $ARG,setsockopt-int=1:2:1,fork EXEC:"echo DATA"

kill $HEARTBEAT_PID >/dev/null 2>&1

rm -f $PEERDIR/.pid
