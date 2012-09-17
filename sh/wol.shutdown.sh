#!/bin/bash

# automatically shutdown the server if a wol package is received and
# the destination address equals the receiving interface address

while [ true ]
do
    socat -s UDP4-RECVFROM:9,ip-pktinfo SYSTEM:"/bin/bash -c '\"[ \$SOCAT_IP_DSTADDR == \$SOCAT_IP_LOCADDR ] && shutdown -h now\"'"
done

