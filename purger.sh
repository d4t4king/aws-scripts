#!/bin/bash

if [ `id -u` -eq 0 ]; then
	apt-get update && apt-get upgrade -y && apt-get autoremove -y

	for P in `dpkg -l | grep "^rc" | awk '{ print $2 }'`; do
		dpkg --purge ${P}
	done
else
	echo "You must be root to run this action."
fi

