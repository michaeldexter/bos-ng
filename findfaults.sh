#!/bin/sh

#set -e

OPLIST=`sh listallopts.sh`

ODIR=/usr/obj/`pwd`
RDIR=${ODIR}/_.result
export ODIR RDIR

for o in $OPLIST
do
#	md=`echo "${o}=foo" | md5`
	md="${o}"
	m=${RDIR}/$md

	if [ ! -f $m/bw/_.bw ] ; then
		continue
	fi

	grep -m 1 -q stopped $m/bw/_.bw
	
	if [ $? = 0 ] ; then
		echo '------------------------------------------------'
		cat $m/src.conf | cut -d = -f1
		grep -m 1 -B 10 stopped $m/bw/_.bw
		cat $m/src.conf
	fi
	
done

echo '------------------------------------------------'
