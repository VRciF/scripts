#!/bin/bash

# usage example: ./exec.sigterm.sh echo "hello world"

trap "$*" SIGTERM

mkfifo /tmp/sigterm.pipe.$$
cat </tmp/sigterm.pipe.$$ > /dev/null & pid=$!

wait $pid

rm /tmp/sigterm.pipe.$$

kill -SIGKILL $pid
