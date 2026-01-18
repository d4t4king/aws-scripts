#!/bin/bash

# change to the specified directory and update nmap from source
DIR=$1

if [ "${DIR}x" == "x" ]; then
	echo "You must specify a directory where the nmap source lives."
	exit -1
else
	pushd $DIR
	make clean
	svn update
	./configure
	make
	popd
fi
