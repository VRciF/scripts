#!/bin/bash

# restarts an executed command every n seconds

SECONDS=$1
shift

while true; do
    echo "$@"
    /bin/bash -c "$@" 2>&1
    sleep $SECONDS
done

