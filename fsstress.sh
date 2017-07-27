#!/bin/bash

. ./variables

# Don't modify these
TABLE="0 $(blockdev --getsz $REPLAYDEV) log-writes $REPLAYDEV $LOGDEV"
dmsetup create log --table "$TABLE"
$MKFS -F /dev/mapper/log
dmsetup message log 0 mark $START_MARK

mount /dev/mapper/log $TEST_MNT
#$FSSTRESS -s 1500835291 -d $TEST_MNT -n 10000 -l 1 -p 16
$FSSTRESS  -d $TEST_MNT -n 10000 -l 1 -p 16
umount $TEST_MNT
dmsetup remove log
