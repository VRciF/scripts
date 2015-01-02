# P2Pd - peer to peer daemon
## What's it all about?
p2pd.sh is a shell script, called *peer*, which uses socat to listen on a command line given udp-port for heartbeat packets
of other p2pd.sh daemons.
The heartbeat packets are use'd to generate a list of known peers of the network.
p2pd.sh uses find to search for executable scripts in a command line given directory, called *peer-directory*, and uses
inotifywait to detect modifications in peer-directory.
The executables found in peer-directory are so called *services*. The name of known local services are distributed to
all known peers using UDP in a given interval.
Thus every p2pd.sh peer in the network generates a list of all services every peer hosts and is then able to
call those services and send arbitrary data to the services.
Since a service is an executable the received data for the services is streamed to the executables stdin.

So the purpose of p2pd.sh is to create a flexible network of peers providing services using executables.
Flexible means that peers can be added/removed at any time by starting/stopping a p2pd.sh instance and
services can be added/removed by adding/removing executables during p2pd.sh runtime in it's given peer-directory.
