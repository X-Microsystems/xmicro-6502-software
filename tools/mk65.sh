#!/bin/bash
#al.sh SOURCEDIR DESTDIR OUTFILE LINKERCONF

rm -rf /tmp/cc65

set -e

mkdir /tmp/cc65

if [ -z $1 ]
then
	SOURCEDIR=src
else
	SOURCEDIR=$1
fi

if [ -z $2 ]
then
	DESTDIR=bin
else
	DESTDIR=$2
fi

if [ -z $3 ]
then
	OUTFILE=a.out
else
	OUTFILE=$3
fi

if [ -z $4 ]
then
	LINKERCONF=$SOURCEDIR/`ls $SOURCEDIR | grep -m 1 ".[cC][fF][gG]$"`
else
	LINKERCONF=$4
fi


#Assemble all ASM sources to a temporary directory
find $SOURCEDIR/*.[sS] -maxdepth 3 -type f -execdir ca65 --cpu 65c02 -g -o /tmp/cc65/{}.o -l /tmp/cc65/{}.lst {} \;

cd $DESTDIR

#Link all assembled object files
ld65 -C ../$LINKERCONF --dbgfile `echo $OUTFILE | cut -d . -f 1`.dbg -o $OUTFILE -m `echo $OUTFILE | cut -d . -f 1`.map `find /tmp/cc65/*.[oO] -maxdepth 1 -type f | xargs`

db65.sh $OUTFILE `echo $OUTFILE | cut -d . -f 1`.dbg `echo $OUTFILE | cut -d . -f 1`.lst

#rm -r /tmp/cc65
exit 0
