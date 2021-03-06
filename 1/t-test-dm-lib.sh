#!/bin/bash

. ../t-dm-lib.sh

FIO=/home/okozina/fio-2.1.9/fio

function tdm_checkparams {
	test -n "$JOB" || {
		echo "--job parameter is mandatory" >&2
		return 100
	}

	test -n "$JOBSDIR" || {
		echo "--jobdir parameter is mandatory" >&2
		return 100
	}
}

function tdm_dm_remove() {
	sync
	udevadm settle
	blockdev --flushbufs /dev/mapper/$1
	dmsetup remove --retry $1
}

# $1 device
# $2 test name 
# $3 fio i/o mode
# $4 job file
# $5 run dir
function tdm_test() {
	local old_dir=$(pwd)

	dir="$2-$3"
	pdebug "Running $dir, size:" $(blockdev --getsize64 $1)
	[ -d $5/$dir ] || install -d $5/$dir
	cd $5/$dir
	echo 3 > /proc/sys/vm/drop_caches
	DEV=$1 MODE=$3 BALIGN=$BALIGN BSIZE=$BSIZE RAMP_TIME=$RAMP_TIME \
		RANDSEED=$RANDSEED SIZE=$SIZE $FIO $JOBSDIR/$4 \
		--output=log --bandwidth-log=log
#		--output=log --latency-log=log --bandwidth-log=log
	cd $old_dir
}

# $1 backing device
# $2 test name
# $3 fio i/o mode
# $4 job file
# $5 run dir
function tdm_test_disk() {
	echo "pass" | cryptsetup create -c $CIPHER -s $KEY_SIZE tst_crypt $1
	tdm_test $DM_PATH/tst_crypt $2 $3 $4 $5
	tdm_dm_remove tst_crypt
}

# $1 fio i/o mode
# $2 dm-zero dev bsize
# $3 job name
# $4 run dir
function tdm_test_zero() {
	dmsetup create tst_zero --table "0 $2 zero"
	tdm_test_disk $DM_PATH/tst_zero zero $1 $3 $4
	tdm_dm_remove tst_zero
}

# $1 log dir
function tdm_remove_tmp_log_files() {
find "$1" -type f \( -size 0 -or \! \( -name log -or -name agg_1k_128k.log \) \) \
	-exec rm -f {} \;
}
