#!/bin/bash

trap "$*" SIGTERM

yes > /dev/null & pid=$!
wait $pid

kill -SIGKILL $pid

