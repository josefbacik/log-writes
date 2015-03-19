#!/bin/bash

# Modify these
LOGDEV=
REPLAYDEV=
FSCK=
TEST_MNT=
START_MARK="mkfs"
SNAPSHOTBASE="replay-base"
SNAPSHOTCOW="replay-cow"

# Don't modify these
BLKSIZE=$(blockdev --getsz $REPLAYDEV)
ORIGIN_TABLE="0 $BLKSIZE snapshot-origin $REPLAYDEV"
COW_TABLE=
COW_LOOP_DEV=

_fail()
{
	echo $1
	if [ -n $SNAPDEV ]
	then
		dmsetup remove $SNAPSHOTCOW > /dev/null 2>&1
		dmsetup remove $SNAPSHOTBASE > /dev/null 2>&1
	fi
	losetup -d $COW_LOOP_DEV > /dev/null 2>&1
	exit 1
}

[ -z $LOGDEV ] && exit "Must set logdev and replaydev"
[ -z $REPLAYDEV ] && exit "Must set logdev and replaydev"

echo "creating snapshot base"
echo $ORIGIN_TABLE

# Create a 1tb sparse file
echo "setting up COW TABLE"
dd if=/dev/zero of=cow-dev bs=1M count=1 seek=1048576
COW_LOOP_DEV=$(losetup -f --show cow-dev)
COW_TABLE="0 $BLKSIZE snapshot /dev/mapper/$SNAPSHOTBASE $COW_LOOP_DEV N 8"
TARGET=/dev/mapper/$SNAPSHOTCOW

NUM_ENTRIES=$(./replay-log --log $LOGDEV --num-entries)

# Yes I know it's confusing, but START_MARK is where we want to start our log
# replay from, but --start-mark means start the log replay to replay-log,
# whereas we want to replay up to START_MARK and then carry on from there.

echo "replayin to mark"
ENTRY=$(./replay-log --log $LOGDEV --find --end-mark $START_MARK)
./replay-log --log $LOGDEV --replay $REPLAYDEV --limit $ENTRY || exit 1
let ENTRY+=1
while [ $ENTRY -lt $NUM_ENTRIES ];
do
	echo "replaying entry $ENTRY"
	./replay-log --limit 1 --log $LOGDEV --replay $REPLAYDEV \
		--start $ENTRY || _fail "replay failed"
	dmsetup create $SNAPSHOTBASE --table "$ORIGIN_TABLE"
	if [ $? -ne 0 ]
	then
		# Sometimes this looping is too fast for device-mapper and
		# we get a random EBUSY, so just sleep for a sec and try
		# again.
		sleep 1
		dmsetup create $SNAPSHOTBASE --table "$ORIGIN_TABLE" || \
			_fail "Couldn't dmsetup"
	fi
	dmsetup create $SNAPSHOTCOW --table "$COW_TABLE" || \
		_fail "failed to create snapshot"
	$FSCK $TARGET > /dev/null 2>&1 || _fail "fsck failed at entry $ENTRY"
	mount $TARGET $TEST_MNT || _fail "mount failed at entry $ENTRY"
	umount $TEST_MNT
	$FSCK $TARGET > /dev/null 2>&1 || _fail "fsck failed after mount at " \
		"entry $ENTRY"
	dmsetup remove $SNAPSHOTCOW || _fail "failed to remove snapshot"
	dmsetup remove $SNAPSHOTBASE || _fail "failed to remove base"
	let ENTRY+=1
done
