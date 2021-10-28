#!/bin/sh
# This file is in the public domain

set -ex

if [ "$1" ] ; then
#	OPLIST="$1"
# DEBUG: Verify that this is necessary
	OPLIST="$( echo "$1" | tr " " "\n" )"
else
# DEBUG: Intentionally wrong to induce failure
	OPLIST=`sh listallopts.sh`
fi

echo ; echo DEBUG: OPLIST is: ; echo
echo $OPLIST

MDUNIT=47
export MDUNIT

ODIR=/usr/obj/`pwd`
FDIR=${ODIR}/files
MNT=${ODIR}/_.mnt
RDIR=${ODIR}/_.result
: ${MAKE_JOBS:="-j$(sysctl -n hw.ncpu)"}

export ODIR MNT RDIR FDIR

bw ( ) (
	cd ../../.. 
	make showconfig \
		SRCCONF=${ODIR}/src.conf __MAKE_CONF=/dev/null \
		> ${FDIR}/_.sc 2>&1
	a=$?
	echo retval $a
	if [ $a -ne 0 ] ; then
		exit 1
	fi
	echo Building world
	\time -h make ${MAKE_JOBS} buildworld \
		SRCCONF=${ODIR}/src.conf __MAKE_CONF=/dev/null \
		> ${FDIR}/_.bw 2>&1
	a=$?
	echo retval $a
	if [ $a -ne 0 ] ; then
		exit 1
	fi
	echo Building kernel
	\time -h make ${MAKE_JOBS} buildkernel \
		KERNCONF=GENERIC \
		SRCCONF=${ODIR}/src.conf __MAKE_CONF=/dev/null \
		> ${FDIR}/_.bk 2>&1
	a=$?
	echo retval $a
	if [ $a -ne 0 ] ; then
		exit 1
	fi
	exit 0
)

iw ( ) (
	trap "umount ${MNT} || true" 1 2 15 EXIT
	newfs /dev/md$MDUNIT
	mkdir -p ${MNT}
	mount /dev/md${MDUNIT} ${MNT}

	cd ../../..
	echo Installing world
	\time -h make ${MAKE_JOBS} installworld \
		SRCCONF=${ODIR}/src.conf __MAKE_CONF=/dev/null \
		DESTDIR=${MNT} \
		> ${FDIR}/_.iw 2>&1
	a=$?
	echo retval $a
	if [ $a -ne 0 ] ; then
		exit 1
	fi
	df -h ${MNT}
	cd etc
	echo Making distribution
	\time -h make distribution \
		SRCCONF=${ODIR}/src.conf __MAKE_CONF=/dev/null \
		DESTDIR=${MNT} \
		> ${FDIR}/_.etc 2>&1
	a=$?
	echo retval $a
	if [ $a -ne 0 ] ; then
		exit 1
	fi
	cd ..
	echo Installing kernel
	\time -h make ${MAKE_JOBS} installkernel \
		KERNCONF=GENERIC \
		DESTDIR=${MNT} \
		SRCCONF=${ODIR}/src.conf __MAKE_CONF=/dev/null \
		> ${FDIR}/_.ik 2>&1
	a=$?
	echo retval $a
	if [ $a -ne 0 ] ; then
		exit 1
	fi
	df -h ${MNT}

	sync ${MNT}
	( cd ${MNT} && mtree -c ) > ${FDIR}/_.mtree
	( cd ${MNT} && du ) > ${FDIR}/_.du
	( df -i ${MNT} ) > ${FDIR}/_.df
	echo success > ${FDIR}/_.success
	sync
	sleep 1
	sync
	sleep 1
	trap "" 1 2 15 EXIT
	umount ${MNT}
	echo "iw done"
)

echo Unmounting and detaching imgfile, if mounted or attached
trap "umount ${MNT} || true; mdconfig -d -u $MDUNIT" 1 2 15 EXIT

# DEBUG: Alternative one to try
umount $MNT || true
mdconfig -d -u $MDUNIT || true

# DEBUG: Alternative two to try
# DEBUG: This alternative a-la-carte testing may be failing because of set -ex
# DEBUG: Verify it
#mount | grep "$MNT"	# Exits upon failure
#test -d ${MNT}/usr	# Alternative test with "test"
#a=$?
#echo retval is $a
#if [ $a = 0 ] ; then
#	umount $MNT
#if

#test -c /dev/$MDUNIT
#a=$?
#echo retval is $a
#if [ $a = 0 ] ; then
#	mdconfig -du $MDUNIT
#if

# Clean and recreate the output directory

#if true ; then	# DEBUGL WHY? Just more set -e compensation?
	echo "=== Clean and recreate output directory as needed"

# Condition 1: Greenfield. No /usr/obj exists
if [ ! -d /usr/obj ] ; then
	echo ; echo No /usr/obj found ; echo
	mkdir -p ${ODIR} ${FDIR} ${MNT}
# Condition 2: Reference build exists
elif [ -f ${RDIR}/Ref/_.success ] ; then 
	echo ; echo Reference build found in object directory ; echo
	# Could one have only the reference?
	chflags -R noschg ${RDIR}/WITH* || true
	rm -rf ${RDIR}/WITH* || true
	mkdir -p ${RDIR}
	[ -d ${FDIR} ] || mkdir ${FDIR}
	[ -d ${MNT} ] || mkdir ${MNT}
# Condition 3: /usr/obj exists in unknown state
else
	echo ; echo Unknown output directory state ; echo
	chflags -R noschg /usr/obj
	rm -rf /usr/obj/*
	mkdir -p ${ODIR} ${FDIR} ${MNT}
fi
#fi		# DEBUG: WHY?

# Moving this as an image may exist from a prevoius run
#echo DEBUG: Unmounting and detaching imgfile, regardless of state
#trap "umount ${MNT} || true; mdconfig -d -u $MDUNIT" 1 2 15 EXIT

#umount $MNT || true
#mdconfig -d -u $MDUNIT || true

echo ; echo DEBUG: Creating initial imgfile ; echo
dd if=/dev/zero of=${ODIR}/imgfile bs=1m count=4096
echo ; echo DEBUG: Attaching imgfile ; echo
mdconfig -a -t vnode -f ${ODIR}/imgfile -u $MDUNIT

# Build & install the reference world

#if true ; then 
if [ ! -d ${RDIR}/Ref ] ; then
	echo "=== Build reference world"
	echo '' > ${ODIR}/src.conf
	MAKEOBJDIRPREFIX=$ODIR/_.ref 
	export MAKEOBJDIRPREFIX
	bw
	echo "=== Install reference world"
	mkdir -p ${RDIR}/Ref
	iw
echo ; echo DEBUG: Moving ${FDIR} contents to ${RDIR}/Ref ; echo
	mv ${FDIR}/_.* ${RDIR}/Ref
fi

# Parse option list into subdirectories with src.conf files.

if true ; then
#	rm -rf ${RDIR}/[0-9a-f]*
# DEBUG: WHY this if the entire RDIR was purged initially?
#	rm -rf ${RDIR}/WITH*
echo ; echo DEBUG: Creating option directories ; echo
	for o in $OPLIST
	do
		echo "${o}=foo" > ${FDIR}/_src.conf
#		m=`md5 < ${FDIR}/_src.conf`
		mkdir -p ${RDIR}/$o
		mv ${FDIR}/_src.conf ${RDIR}/$o/src.conf
	done
echo ; echo DEBUG: Listing option directory ; echo
ls ${RDIR}
fi

# Run through each testtarget in turn

if true ; then
#	for d in ${RDIR}/[0-9a-z]*
echo ; echo DEBUG: Stepping through option directories ; echo
	for d in ${RDIR}/WITH*
	do
		if [ ! -d $d ] ; then
			continue;
		fi
		echo ; echo '------------------------------------------------'
		cat $d/src.conf
		echo '------------------------------------------------' ; echo
		cp $d/src.conf ${ODIR}/src.conf

		if [ ! -f $d/iw/done ] ; then
			MAKEOBJDIRPREFIX=$ODIR/_.ref
			export MAKEOBJDIRPREFIX
			echo "# BW(ref)+IW(ref) `cat $d/src.conf`"
			rm -rf $d/iw
			mkdir -p $d/iw
			iw || true
			mv ${FDIR}/_.* $d/iw || true
			touch $d/iw/done
		fi
		if [ ! -f $d/bw/done ] ; then
			MAKEOBJDIRPREFIX=$ODIR/_.tst 
			export MAKEOBJDIRPREFIX
			echo "# BW(opt) `cat $d/src.conf`"
			rm -rf $d/w $d/bw
			mkdir -p $d/w $d/bw
			if bw ; then
				mv ${FDIR}/_.* $d/bw || true

				echo "# BW(opt)+IW(opt) `cat $d/src.conf`"
				iw || true
				mv ${FDIR}/_.* $d/w || true
				touch $d/w/done

				echo "# BW(opt)+IW(ref) `cat $d/src.conf`"
				echo '' > ${ODIR}/src.conf
				iw || true
				mv ${FDIR}/_.* $d/bw || true
				touch $d/bw/done
			else
				mv ${FDIR}/_.* $d/bw || true
				touch $d/bw/done $d/w/done
# DEBUG: Seen once: option_survey-check4refrun.sh: /w/done: not found
			fi
		fi
	done
fi
