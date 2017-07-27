#!/bin/bash

. ./variables

[ -z $LOGDEV ] && exit "Must set logdev and replaydev"
[ -z $REPLAYDEV ] && exit "Must set logdev and replaydev"

NUM_ENTRIES=$(./replay-log --log $LOGDEV --num-entries)

# Yes I know it's confusing, but START_MARK is where we want to start our log
# replay from, but --start-mark means start the log replay to replay-log,
# whereas we want to replay up to START_MARK and then carry on from there.


dd if=/dev/zero of=cow-dev bs=1M count=1 seek=1048576 > /dev/null 2>&1
echo "replayin to mark"
ENTRY=$(./replay-log --log $LOGDEV --find --end-mark $START_MARK)
./replay-log --log $LOGDEV --replay $REPLAYDEV --limit $ENTRY || exit 1
let ENTRY+=1
./replay-log --check 1000 --log $LOGDEV --replay $REPLAYDEV --start $ENTRY \
	--fsck ./replay-fsck-wrapper.sh
