#!/bin/bash

CHFLAGS=`which chflags`
FLAG_SET="dump,nouappnd,nouchange,noopaque,noarch,nohidden"

if [ -z "$CHFLAGS" ]; then
	echo "Are you running this on OSX?"
	exit 0
fi

echo "Fixing up HFS+ attributes that Linux probably screwed up..."
echo "I will need sudo priviledge for this..."

D=${1:-$TOP}
if [ -z "$D" ]; then
	echo -n "Please specify a directory: "
	read D
fi
if [ -z "$D" ]; then
	echo "whatever."
	exit
fi

if [ "$D" = "$TOP" ]; then
	echo "WARNING: Only running on the Android tree."
	echo "         Pass a directory to this script to change that..."
fi

echo "Fixing up '$D'..."
sudo find $D -exec $CHFLAGS $FLAG_SET {} \;

