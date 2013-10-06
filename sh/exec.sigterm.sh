#!/bin/bash

# execute a script on sigterm signal
# usage example: ./exec.sigterm.sh echo "hello world\!"

# $* contains the command line params as a string - so register script execution on trap
trap "$*" SIGTERM

mkfifo /tmp/sigterm.pipe.$$
cat </tmp/sigterm.pipe.$$ > /dev/null & pid=$!

wait $pid

rm /tmp/sigterm.pipe.$$

kill -SIGKILL $pid 2>&1
