#!/bin/sh

#set -e

OPLIST=`sh listallopts.sh`

ODIR=/usr/obj/`pwd`
RDIR=${ODIR}/_.result
export ODIR RDIR


start_timestamp=$( stat -f %m $RDIR/Ref/_.sc )
stop_timestamp=$( stat -f %m $RDIR/Ref/_.success )

#exectime=$( expr $stop_timestamp - $start_timestamp )
exectime=$(( $stop_timestamp - $start_timestamp ))
refminutes=$(( $exectime / 60 ))

#echo Ref start $start_timestamp
#echo Ref stop $stop_timestamp
echo Reference build $exectime seconds, $refminutes minutes

refbytes=$( cat $RDIR/Ref/_.df | tail -1 | cut -d " " -f6 )
refmbytes=$(( $refbytes / 1024 ))
refgbytes=$(( $refmbytes / 1024 ))

echo check this math as its probably wrong
echo $refbytes bytes $refmbytes megabytes $refgbytes gigabytes

for o in $OPLIST
do
#	md=`echo "${o}=foo" | md5`
	md="${o}"
	m=${RDIR}/$md
	[ -d $m/src.conf ] || continue
	option=$( cat $m/src.conf | cut -d = -f1 )

[ -d $m ] || continue
[ -f $m/bw/_.bw ] || continue
[ -f $m/w/_.iw ] || continue
[ -f $m/stats ] || continue

grep -q -m 1 stopped $m/bw/_.bw && continue


	[ -f $m/bw/_.sc ] || continue
	[ -f $m/w/done ] || continue
	start_timestamp=$( stat -f %m $m/bw/_.sc )
	stop_timestamp=$( stat -f %m $m/w/done ) || continue

	#exectime=$( expr $stop_timestamp - $start_timestamp )
	exectime=$(( $stop_timestamp - $start_timestamp ))

	minutes=$(( $exectime / 60 ))

#	echo $option start $start_timestamp
#	echo $option stop $stop_timestamp
	echo $option $exectime seconds, $minutes minutes

	kbytes=$( grep r-w $m/stats | cut -d " " -f9 )
	echo $kbytes kbytes
done

fullstart_timestamp=$( stat -f %m $ODIR/_.mnt )
fullstop_timestamp=$( stat -f %m $ODIR/imgfile )
fulltime=$(( $fullstop_timestamp - $fullstart_timestamp ))
fullminutes=$(( $fulltime / 60 ))
fullhours=$(( $fullminutes / 60 ))

echo Full run $fulltime seconds $fullminutes minutes $fullhours hours


