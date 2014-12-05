#!/bin/bash

[ $# -ne 2 ] && echo "Usage: replay-individual.sh <logdev> <replaydev>" && \
	exit 1

LOGDEV=$1
REPLAYDEV=$2

NUM_ENTRIES=$(./replay-log --log $LOGDEV --num-entries)
ENTRY=2265
./replay-log --log $LOGDEV --verbose --replay $REPLAYDEV --limit $ENTRY || exit 1
let ENTRY+=1
while [ $ENTRY -lt $NUM_ENTRIES ];
do
	./replay-log --limit 1 --log $LOGDEV --replay $REPLAYDEV --start \
		$ENTRY --verbose || exit 1
	btrfsck /dev/sda > /dev/null 2>&1 || exit 1
	let ENTRY+=1
done
