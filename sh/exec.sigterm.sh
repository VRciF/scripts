#!/bin/bash

# usage example: ./exec.sigterm.sh echo "hello world"

trap "$*" SIGTERM

yes > /dev/null & pid=$!
wait $pid

kill -SIGKILL $pid

