#!/bin/bash

function notify_peer_modification(){
    PEERDIR="$1"
    while read SCRIPT; do
        SCRIPT="$PEERDIR/p-mod.d/$SCRIPT"
        if [ -x "$SCRIPT" ]; then
            exec $SCRIPT >/dev/null 2>&1
        fi
    done < <(ls -1 $PEERDIR/p-mod.d 2>/dev/null)
}

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

    touch "$PEERDIR/.p2pd/peers"
    touch "$PEERDIR/.p2pd/services"

    case "$COMMAND" in
        "HB")
            PREVIFS="$IFS"
            IFS=':' read PEERUUID PEERNAME PEERPORT <<< "$NAMESPACE"
            IFS=$PREVIFS

            (
                flock -x 200
                touch "$PEERDIR/.p2pd/peers.tmp"

                PCNT=$(grep -c "$PEERUUID:$PEERNAME:$SOCAT_PEERADDR:$PEERPORT" "$PEERDIR/.p2pd/peers")
                if [ "$PCNT" -eq "0" ]; then
                    PEERADDR=$SOCAT_PEERADDR
                    P2P_TASK="peer-up"
                    export PEERUUID
                    export PEERNAME
                    export PEERADDR
                    export PEERPORT
                    export P2P_TASK

                    # call "new-peer" script'
                    notify_peer_modification "$PEERDIR"
                fi

                # remove current heartbeat peer
                grep -v "$PEERUUID:$PEERNAME:$SOCAT_PEERADDR:$PEERPORT" "$PEERDIR/.p2pd/peers" > "$PEERDIR/.p2pd/peers.tmp"
                mv "$PEERDIR/.p2pd/peers.tmp" "$PEERDIR/.p2pd/peers"

                cat - > "$PEERDIR/.p2pd/heartbeat.$PEERUUID"

                # add heartbeat to peers
                echo "$PEERUUID:$PEERNAME:$SOCAT_PEERADDR:$PEERPORT" >> "$PEERDIR/.p2pd/peers"
                sort -u -o "$PEERDIR/.p2pd/peers" "$PEERDIR/.p2pd/peers"
            ) 200<"$PEERDIR/.p2pd/peers"
            ;;
        "PEERS")
            (
                flock -x 200
                touch "$PEERDIR/.p2pd/peers.tmp"

                while read LINE || [ -n "$LINE" ]; do
                    echo "$LINE" >> "$PEERDIR/.p2pd/peers"
                done

                sort -u -o "$PEERDIR/.p2pd/peers" "$PEERDIR/.p2pd/peers"
            ) 200<"$PEERDIR/.p2pd/peers"
            ;;
        "SERVICES")
            PEERUUID=$NAMESPACE
            if [ "$UUID" != "$PEERDIR" ]; then
                (
                    flock -x 200

                    PEERLINE=$(grep "$PEERUUID" "$PEERDIR/.p2pd/peers")
                    PREVIFS="$IFS"
                    IFS=':' read PEERUUID PEERNAME PEERADDR PEERPORT <<< "$PEERLINE"
                    IFS=$PREVIFS

                    while read SERVICE || [ -n "$SERVICE" ]; do
	                    # create directories for services
	                    SERVICEPATH=$(dirname $SERVICE)
	                    SERVICENAME=$(basename $SERVICE)
	                    if [ ! -d "$PEERDIR/p-peer-services.d/by-uuid/$PEERUUID/$SERVICEPATH" ]; then
	                        mkdir -p "$PEERDIR/p-peer-services.d/by-uuid/$PEERUUID/$SERVICEPATH" 2>/dev/null
	                    fi
	                    if [ ! -d "$PEERDIR/p-peer-services.d/by-ip/$PEERADDR:$PEERPORT/$SERVICEPATH" ]; then
	                        mkdir -p "$PEERDIR/p-peer-services.d/by-ip/$PEERADDR:$PEERPORT/$SERVICEPATH" 2>/dev/null
	                    fi
	                    if [ ! -d "$PEERDIR/p-peer-services.d/by-name/$PEERNAME/$SERVICEPATH" ]; then
	                        mkdir -p "$PEERDIR/p-peer-services.d/by-name/$PEERNAME/$SERVICEPATH" 2>/dev/null
	                    fi
	                    if [ ! -d "$PEERDIR/p-peer-services.d/by-service/$SERVICEPATH" ]; then
	                        mkdir -p "$PEERDIR/p-peer-services.d/by-service/$SERVICEPATH" 2>/dev/null
	                    fi

	                    if [ ! -f "$PEERDIR/p-peer-services.d/by-uuid/$PEERUUID/$SERVICEPATH/$SERVICENAME" ]; then
	                        ln -s "$SCRIPT" "$PEERDIR/p-peer-services.d/by-uuid/$PEERUUID/$SERVICEPATH/$SERVICENAME" 2>/dev/null
	                    fi
	                    if [ ! -f "$PEERDIR/p-peer-services.d/by-ip/$PEERADDR:$PEERPORT/$SERVICEPATH/$SERVICENAME" ]; then
	                        ln -s "$SCRIPT" "$PEERDIR/p-peer-services.d/by-ip/$PEERADDR:$PEERPORT/$SERVICEPATH/$SERVICENAME" 2>/dev/null
	                    fi
	                    if [ ! -f "$PEERDIR/p-peer-services.d/by-name/$PEERNAME/$SERVICEPATH/$SERVICENAME" ]; then
	                        ln -s "$SCRIPT" "$PEERDIR/p-peer-services.d/by-name/$PEERNAME/$SERVICEPATH/$SERVICENAME" 2>/dev/null
	                    fi
	                    if [ ! -f "$PEERDIR/p-peer-services.d/by-service/$SERVICEPATH/$SERVICENAME" ]; then
	                        ln -s "$SCRIPT" "$PEERDIR/p-peer-services.d/by-service/$SERVICEPATH/$SERVICENAME" 2>/dev/null
	                    fi

	                    touch -h "$PEERDIR/p-peer-services.d/by-uuid/$PEERUUID/$SERVICEPATH/$SERVICENAME" 2>/dev/null
	                    touch -h "$PEERDIR/p-peer-services.d/by-ip/$PEERADDR:$PEERPORT/$SERVICEPATH/$SERVICENAME" 2>/dev/null
	                    touch -h "$PEERDIR/p-peer-services.d/by-name/$PEERNAME/$SERVICEPATH/$SERVICENAME" 2>/dev/null
	                    touch -h "$PEERDIR/p-peer-services.d/by-service/$PEERNAME/$SERVICEPATH/$SERVICENAME" 2>/dev/null

	                    PCNT=$(grep -c "$PEERUUID:$SERVICE" "$PEERDIR/.p2pd/services")
	                    if [ "$PCNT" -eq "0" ]; then
	                        PEERSERVICE="$SERVICE"
	                        PEERADDR=$SOCAT_PEERADDR
	                        P2P_TASK="service-up"
	                        export PEERUUID
	                        export PEERSERVICE
	                        export PEERNAME
	                        export PEERADDR
	                        export P2P_TASK
	
	                        # call "service up" script
	                        notify_peer_modification "$PEERDIR"
	                    fi

                        echo "$PEERUUID:$SERVICE" >> "$PEERDIR/.p2pd/services"
                    done
    
                    sort -u -o "$PEERDIR/.p2pd/services" "$PEERDIR/.p2pd/services"
                ) 200<"$PEERDIR/.p2pd/services"
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

            RELATIVE=$(printf "/%s" "${parts[@]}")
            RELATIVE=${RELATIVE:1}

            if [ -x "$PEERDIR/$RELATIVE.sh" ]; then
                RELATIVE="$RELATIVE.sh"
            fi

            if [ -x "$PEERDIR/$RELATIVE" ]; then
                P2PD_TID="$TRANSACTIONO"
                P2PD_PNO="$PARTNO"
                export P2PD_TID
                export P2PD_PNO

                exec $PEERDIR/$RELATIVE <&0

            fi
            ;;
    esac

    # clean up of peers and services
    (
        flock -x 200

        HBINTERVALLIMITINMINS=$(($HEARTBEATINTERVAL*5/60))
        HBLIMIT=$((START-$HEARTBEATINTERVAL*5))

        BYUUIDPEERDIR="$PEERDIR/p-peer-services.d/by-uuid"
        while read $SERVICEUUIDPATH; do
            if [ "${#SERVICEUUIDPATH}" -eq "0" ]; then
                continue
            fi

            MODIFICATION=$(stat -c %Y "$SERVICEUUIDPATH")

            if [[ "$MODIFICATION" -gt "$HBLIMIT" ]]; then
                # this service shall get droped
                UUIDRELPATH=${SERVICEUUIDPATH#$BYUUIDPEERDIR}

                PREVIFS="$IFS"
                IFS='/' read PEERUUID <<< "$UUIDRELPATH"
                IFS=$PREVIFS

                PEERSERVICE=${UUIDRELPATH#$PEERUUID}
                find "$BYUUIDPEERDIR" -path "*/$PEERSERVICE" -delete
                rm "$SERVICEUUIDPATH"

                grep -v "$PEERSERVICE" "$PEERDIR/.p2pd/services" > "$PEERDIR/.p2pd/services.tmp"
                mv "$PEERDIR/.p2pd/services.tmp" "$PEERDIR/.p2pd/services"

                PEERLINE=$(grep "$PEERUUID" "$PEERDIR/.p2pd/peers")
                PREVIFS="$IFS"
                IFS=':' read PEERUUID PEERNAME PEERADDR PEERPORT <<< "$PEERLINE"
                IFS=$PREVIFS

                P2P_TASK="service-down"
                export PEERUUID
                export PEERNAME
                export PEERADDR
                export PEERPORT
                export PEERSERVICE
                export P2P_TASK

                notify_peer_modification "$PEERDIR"
            fi

        done < <(find "$BYUUIDPEERDIR" -type l -mmin +$HBINTERVALLIMITINMINS)

        # remove peers whose heartbeat is older than HEARTBEATINTERVAL*5 day
        touch "$PEERDIR/.p2pd/peers.tmp"

        while read LINE || [ -n "$LINE" ]; do
            if [ "${#LINE}" -eq 0 ]; then
                continue
            fi

            PREVIFS="$IFS"
            IFS=':' read PEERUUID PEERNAME PEERADDR PEERPORT <<< "$LINE"
            IFS=$PREVIFS

            TIMESTAMP=0
            if [ -f "$PEERDIR/.p2pd/heartbeat.$PEERUUID" ]; then
                TIMESTAMP=$(stat -c %Y "$PEERDIR/.p2pd/heartbeat.$PEERUUID")
            fi

            if [[ "$TIMESTAMP" -gt "$HBLIMIT" && "$UUID" != "$PEERDIR" ]]; then
                echo "$LINE" >> "$PEERDIR/.p2pd/peers.tmp"
            else
                rm -f "$PEERDIR/.p2pd/heartbeat.$PEERUUID"

                PEERADDR=$SOCAT_PEERADDR
                P2P_TASK="peer-down"
                export PEERUUID
                export PEERNAME
                export PEERADDR
                export PEERPORT
                export P2P_TASK

                SCNT=0
                while read SLINE; do
                    PREVIFS="$IFS"
                    IFS=':' read PEERUUID SERVICE <<< "$SLINE"
                    IFS=$PREVIFS

                    eval SERVICE_$SCNT="$SERVICE"
                    eval export SERVICE_$SCNT
                    SCNT=$(($SCNT+1))
                done < <(grep "$PEERUUID:" "$PEERDIR/.p2pd/services")

                # call "remove-peer" script'
                notify_peer_modification "$PEERDIR"

                grep -v "$PEERUUID:" "$PEERDIR/.p2pd/services" > "$PEERDIR/.p2pd/services.tmp"
                mv "$PEERDIR/.p2pd/services.tmp" "$PEERDIR/.p2pd/services"

                find "$PEERDIR/p-peer-services.d" -type d -empty -delete
            fi
        done <"$PEERDIR/.p2pd/peers"

        mv "$PEERDIR/.p2pd/peers.tmp" "$PEERDIR/.p2pd/peers"
    ) 200<"$PEERDIR/.p2pd/peers"

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

    touch "$PEERDIR/.p2pd/peers"
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
    done < <(grep -v "$PEER" "$PEERDIR/.p2pd/peers")
    ) 200<"$PEERDIR/.p2pd/peers"
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
        done < "$PEERDIR/.p2pd/peers"
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

        inotifywait -e close_write -e attrib --exclude '(\.p2pd|p-mod.d|p-peer-services.d).*' -r -q -t $HEARTBEATINTERVAL "$PEERDIR" >>/tmp/inotify.log 2>&1
    done
}

function call_service() {
    PEERDIR=$1
    SERVICENAME=$2
    DESTINATIONHOSTS=$3
    REGEX=""
    RELIABLE=$4

    if [ "${#DESTINATIONHOSTS}" -ne "0" ]; then
	    PREVIFS=$IFS
	    IFS=':' read -a parts <<< "$DESTINATIONHOSTS"
	    IFS=$PREVIFS

	    REGEX=$(printf "|%s" "${parts[@]}")
	    REGEX=${REGEX:1}
	else
	    DESTINATIONHOSTS=""
	    REGEX=""
	fi

    TID=$(cat /proc/sys/kernel/random/uuid)
    CNT=0

    if [ "$RELIABLE" -eq "1" ]; then
        DESCRIPTORS=()

        # open socat connection to every peer
        CNT=5
        while read LINE; do
            PREVIFS=$IFS
            IFS=':' read PEERUUID PEERNAME PEERADDR PEERPORT <<< "$LINE"
            IFS=$PREVIFS

            SERVICECNT=$(grep -c -e "$PEERUUID.*$SERVICENAME" "$PEERDIR/.p2pd/services")

            if [ "$SERVICECNT" -eq "0" ]; then
                continue;
            fi

            DESCRIPTORS+=($CNT)

            eval "exec $CNT> >(socat STDIO \"TCP:$PEERADDR:$PEERPORT\")"

            CNT=$(($CNT+1))
        done < <(grep -e "$REGEX" "$PEERDIR/.p2pd/peers")

        # send header
        PACKET="EXEC:$TID:-1:$SERVICENAME\n"
        for DESC in "${DESCRIPTORS[@]}"
        do
            eval "echo -n -e \"$PACKET\" >&$DESC"
        done

        # send data
        while [ true ]; do
            HEXPAYLOAD=$(od -A n -v -t x1 -N 8192)
            if [ "${#HEXPAYLOAD}" -eq "0" ];then
                break
            fi
            HEXPAYLOAD="${HEXPAYLOAD// /\\x}"
            HEXPAYLOAD=$(printf '%s' $HEXPAYLOAD)

            PACKET="$HEXPAYLOAD"

            for DESC in "${DESCRIPTORS[@]}"
            do
                eval "echo -n -e \"$PACKET\" >&$DESC"
            done
        done

        # close descriptors
        for DESC in "${DESCRIPTORS[@]}"
        do
            eval "exec $DESC>&-"
        done

    else
	    while [ true ]; do
	        PACKET="EXEC:$TID:$CNT:$SERVICENAME\n"

	        MAXPAYLOADLEN=$(($MTU-${#PACKET}))

	        HEXPAYLOAD=$(od -A n -v -t x1 -N $MAXPAYLOADLEN)
            if [ "${#HEXPAYLOAD}" -eq "0" ];then
                break
            fi
            HEXPAYLOAD="${HEXPAYLOAD// /\\x}"
            HEXPAYLOAD=$(printf '%s' $HEXPAYLOAD)

            PACKET="$PACKET$HEXPAYLOAD"

	        while read LINE; do
	              PREVIFS=$IFS
	              IFS=':' read PEERUUID PEERNAME PEERADDR PEERPORT <<< "$LINE"
	              IFS=$PREVIFS

	              SERVICECNT=$(grep -c -e "$PEERUUID.*$SERVICENAME" "$PEERDIR/.p2pd/services")

                  if [ "$SERVICECNT" -eq "0" ]; then
                      continue;
                  fi

	              echo -n -e "$PACKET" | socat STDIO "UDP-DATAGRAM:$PEERADDR:$PEERPORT"

	        done < <(grep -e "$REGEX" "$PEERDIR/.p2pd/peers")

	    done
    fi
}

function show_current_stats(){
    SHOW=$1

    case "$SHOW" in
    "PEERS")
        cat "$PEERDIR/.p2pd/peers"
        exit 0
        ;;
    "HEARTBEAT")
        cat $PEERDIR/.p2pd/heartbeat.*
        exit 0
        ;;
    "SERVICES")
        cat "$PEERDIR/.p2pd/services"
        exit 0
        ;;
    esac
}

function show_help() {
    >&2 echo "$0 [-h/-?] -d PEERDIR [-i HOST:PORT] [-n NAME] [-l [IP:]PORT] [-b HEARTBEATINTERVAL] [-s PEERS|HEARTBEAT|SERVICES] [-e SERVICENAME] [-g [UUID][:NAME][:...]] [-r]"
    >&2 echo "Options are:"
    >&2 echo "-h/-?                   this help page"
    >&2 echo "-i HOST:PORT            the initial host and port used for heartbeat notifications, used to initialize the p2p network"
    >&2 echo "-n NAME the             name of the current p2pd instance used to identify host(s)"
    >&2 echo "-l [IP:]PORT            the port where to listen for heartbeat packets from peers, if IP is given the corresponding interface will be used"
    >&2 echo "-d PEERDIR              mandatory, used to save current/initial configuration and where the services (executables) can be found"
    >&2 echo "-b HEARTBEATINTERVAL    interval in seconds to notify peers about the daemon being still alive, default 300"
    >&2 echo "-s PEERS|HEARTBEAT|SERVICES    show the current stats for know peers, heartbeat or services"
    >&2 echo "-e SERVICENAME          call the given service"
    >&2 echo "-g UUID:NAME            show the current stats for know peers, heartbeat or services"
    >&2 echo "-r                      execute service call using TCP (reliable) instead of UDP"
}

command -v socat >/dev/null 2>&1 || { echo >&2 "ERROR: I require 'socat' but it's not installed.  Aborting."; exit 1; }
command -v od >/dev/null 2>&1 || { echo >&2 "ERROR: I require 'od' but it's not installed.  Aborting."; exit 1; }

ISSYMLINK=0
if [ -L "$0" ]; then
    ISSYMLINK=1
fi
pushd `dirname $0` > /dev/null
SYMBOLICSCRIPTPATH=`pwd -P`
popd > /dev/null
SYMBOLICSCRIPTNAME=`basename $0`
SYMBOLICSCRIPT="$SYMBOLICSCRIPTPATH/$SYMBOLICSCRIPTNAME"

SCRIPT=`readlink -f $0`
SCRIPTPATH=`dirname "$SCRIPT"`
SCRIPTNAME=`basename $SCRIPT`

P2PSERVICESD="/p-peer-services.d/"
if [ "${SYMBOLICSCRIPTPATH/$P2PSERVICESD}" != "$SYMBOLICSCRIPTPATH" ] ; then
    PEERDIR="${SYMBOLICSCRIPTPATH/$P2PSERVICESD*}"
fi

START=$(date +%s)
UUID=$(cat /proc/sys/kernel/random/uuid)

#set -x

# directory where client executable scripts reside
if [ -z "$PEERDIR" ]; then
    PEERDIR=""
fi

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
RELIABLE=0

# load options from config file
if [ -f "$PEERDIR/.p2pd/p2pd.cfg" ]; then
    source "$PEERDIR/.p2pd/p2pd.cfg"
fi

# save command line options
while getopts "h?i:n:l:d:b:s:e:g:xr" opt; do
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
    r)  RELIABLE=1
        ;;
    esac
done

#for argv in "$@"; do
#    case "$argv" in
#        "-udp")
#            RELIABLE=0
#            ;;
#        "-tcp")
#            RELIABLE=1
#            ;;
#    esac
#done

# validate command line options
if [ ! -d "$PEERDIR" ]; then
    >&2 echo "ERROR: given peerdirectory '$PEERDIR' not a directory"
    show_help
    exit 1
fi

# get absolute peerdir path
PEERDIR=`readlink -f $PEERDIR`

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

############### at this point correct command line arguments are given ###############

mkdir -p "$PEERDIR/.p2pd"
mkdir -p "$PEERDIR/p-mod.d"
mkdir -p "$PEERDIR/p-peer-services.d/by-uuid"
mkdir -p "$PEERDIR/p-peer-services.d/by-ip"
mkdir -p "$PEERDIR/p-peer-services.d/by-name"
mkdir -p "$PEERDIR/p-peer-services.d/by-service"

P2PSERVICESD="/p-peer-services.d/"
if [ "${SYMBOLICSCRIPT/$P2PSERVICESD}" != "$SYMBOLICSCRIPT" ] ; then
    # the symbolicscriptpath determines which remote script to call and forward stdin to the destination

    # substring replace P2PSERVICESD by empty string
    SERVICE="${SYMBOLICSCRIPT/$PEERDIR$P2PSERVICESD/}"

    # split by 
	PREVIFS=$IFS
	IFS='/' read -a parts <<< "$SERVICE"
	IFS=$PREVIFS

    EXECUTEDESTINATION=""

	DESTINATIONTYPE=${parts[0]}
	unset parts[0]
	if [ "$DESTINATIONTYPE" != "by-service" ]; then
	    EXECUTEDESTINATION=${parts[1]}
	    unset parts[1]
	fi

	EXECUTESERVICE=$(printf "/%s" "${parts[@]}")
	EXECUTESERVICE=${EXECUTESERVICE:1}
	unset parts
fi
# if a peer's service shall be called
if [ "${#EXECUTESERVICE}" -ne "0" ]; then
    call_service "$PEERDIR" "$EXECUTESERVICE" "$EXECUTEDESTINATION" "$RELIABLE"
    exit 0
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

# save current daemon pid
echo "$$" > "$PEERDIR/.p2pd/pid"

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
echo "NAME=$NAME" > "$PEERDIR/.p2pd/p2pd.cfg"
echo "UUID=$UUID" >> "$PEERDIR/.p2pd/p2pd.cfg"
echo "PORT=$PORT" >> "$PEERDIR/.p2pd/p2pd.cfg"
echo "INITNODE=$INITNODE" >> "$PEERDIR/.p2pd/p2pd.cfg"
echo "HEARTBEATINTERVAL=$HEARTBEATINTERVAL" >> "$PEERDIR/.p2pd/p2pd.cfg"
echo "MTU=$MTU" >> "$PEERDIR/.p2pd/p2pd.cfg"

# parse given listen PORT for host part
# if a host is given it is used as multicast address
PREVIFS=$IFS
PREVIFS=$IFS
IFS=':' read -a parts <<< "$PORT"
IFS=$PREVIFS

cnt=${#parts[@]}
PORT=${parts[$(($cnt-1))]}
unset parts[$(($cnt-1))]
HOST=$(printf ":%s" "${parts[@]}")
HOST=${HOST:1}
unset parts

export PEERDIR

heartbeat_task "$NAME" "$PEERDIR" $PORT $HEARTBEATINTERVAL "$INITNODE" $START &
HEARTBEAT_PID=$!

UDPARG="UDP-RECVFROM:$PORT"
TCPARG="TCP-LISTEN:$PORT"
if [ "${#HOST}" -ne "0" ]; then
	if [[ $HOST =~ ^(ff|2(2[4-9]|3[0-9])) ]]; then
	    UDPARG="UDP-RECVFROM:$PORT,ip-add-membership=$HOST"
	else
	    UDPARG="UDP-RECVFROM:$PORT,bind=$HOST"
	    TCPARG="TCP-LISTEN:$PORT,bind=$HOST"
	fi
fi

socat $UDPARG,setsockopt-int=1:2:1,fork EXEC:"$0 -x -d '$PEERDIR'" &
SOCAT_UDP_PID=$!
socat $TCPARG,setsockopt-int=1:2:1,fork EXEC:"$0 -x -d '$PEERDIR'" &
SOCAT_TCP_PID=$!

while [ true ]; do
    sleep 60
done

kill $HEARTBEAT_PID >/dev/null 2>&1
kill $SOCAT_UDP_PID >/dev/null 2>&1
kill $SOCAT_TCP_PID >/dev/null 2>&1

rm -f "$PEERDIR/.p2pd/pid"
