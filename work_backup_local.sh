#!/bin/bash

DATE=$(date "+%Y-%m-%d-%H-%M-%S")

echo $DATE

HOSTNAME=$(hostname -f)

echo $HOSTNAME
if [ "${1}x" == "homex" ]; then
	TARBALL="/tmp/home_${HOSTNAME}_${DATE}.tar"
	echo $TARBALL
	tar cvf ${TARBALL} --exclude-backups --exclude="*.iso" /home/ /root/ && xz -9 ${TARBALL}
elif [ "${1}x" == "varx" ]; then
	TARBALL="/tmp/varetc_${HOSTNAME}_${DATE}.tar"
	echo $TARBALL
	tar cvf ${TARBALL} --exclude-backups --exclude=/var/run --exclude=/var/tmp --exclude=/var/spool/clientmqueue --exclude="/var/cache/apt/archive*" /var /etc && xz -9 ${TARBALL}
else
	# Skip any VMs for the full backup.  We should have gotten them in the "home" backup.
	TARBALL="/tmp/full_${HOSTNAME}_${DATE}.tar"
	# This is not how we want to backup the backups, so skip that directory for now.
	if [ "${HOSTNAME}" = "is-vmsbak-p01.sempra.com" ]; then
		tar cvf ${TARBALL} --exclude=/dev --exclude=/tmp --exclude=/proc --exclude=/sys --exclude-backups --exclude=/media --exclude=/mnt --exclude=/var/tmp --exclude=/run --exclude=/var/run --exclude="*.iso" --exclude="*/VirtualBox VMs" --exclude="*/vmware/*" --exclude="*.ova" --exclude=/var/cache/* --exclude=/var/cache --exclude=/opt --exclude=/opt/* / && xz -9 ${TARBALL}
	else
		tar cvf ${TARBALL} --exclude=/dev --exclude=/tmp --exclude=/proc --exclude=/sys --exclude-backups --exclude=/media --exclude=/mnt --exclude=/var/tmp --exclude=/run --exclude=/var/run --exclude="*.iso" --exclude="*/VirtualBox VMs" --exclude="*/vmware/*" --exclude="*.ova" --exclude=/var/cache/* --exclude=/var/cache / && xz -9 ${TARBALL}
	fi
fi

scp "${TARBALL}.xz" 172.18.210.70:/opt/backups/
if [ $? == 0 ]; then
	rm -vf ${TARBALL}
else
	echo "There was a problem copying the tarbal!"
fi
