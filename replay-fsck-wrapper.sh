#!/bin/bash

. variables

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

# Create a 1tb sparse file
COW_LOOP_DEV=$(losetup -f --show cow-dev)
COW_TABLE="0 $BLKSIZE snapshot /dev/mapper/$SNAPSHOTBASE $COW_LOOP_DEV N 8"
TARGET=/dev/mapper/$SNAPSHOTCOW

dmsetup create $SNAPSHOTBASE --table "$ORIGIN_TABLE"
if [ $? -ne 0 ]
then
	sleep 1
	dmsetup create $SNAPSHOTBASE --table "$ORIGIN_TABLE" || \
		_fail "failed to create snapshot base"
fi
		
dmsetup create $SNAPSHOTCOW --table "$COW_TABLE"
if [ $? -ne 0 ]
then
	sleep 1
	dmsetup create $SNAPSHOTCOW --table "$COW_TABLE" || \
		_fail "failed to create snapshot"
fi

mount $TARGET $TEST_MNT || _fail "mount failed at entry $ENTRY"
umount $TEST_MNT
$FSCK -n $TARGET > fsck-output 2>&1 || _fail "fsck failed after mount"
dmsetup remove $SNAPSHOTCOW
if [ $? -ne 0 ]
then
	sleep 1
	dmsetup remove $SNAPSHOTCOW || _fail "failed to remove snapshot"
fi

dmsetup remove $SNAPSHOTBASE
if [ $? -ne 0 ]
then
	sleep 1
	dmsetup remove $SNAPSHOTBASE || _fail "failed to remove base"
fi
losetup -d $COW_LOOP_DEV
exit 0
