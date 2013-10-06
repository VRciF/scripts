#!/bin/bash

# execute a script on sigterm signal
# usage example: ./exec.sigterm.sh echo "hello world\!"

# $* contains the command line params as a string - so register script execution on trap
trap "$*" SIGTERM

mkfifo /tmp/sigterm.pipe.$$
cat </tmp/sigterm.pipe.$$ > /dev/null & pid=$!
rm /tmp/sigterm.pipe.$$

wait $pid

kill -SIGKILL $pid 2>/dev/null
