#!/bin/bash

DATE=$(date "+%Y-%m-%d-%H-%M-%S")

echo $DATE

HOSTNAME=$(hostname -f)

echo $HOSTNAME

if [ "${1}x" == "homex" ]; then
	TARBALL="/tmp/home_${DATE}_${HOSTNAME}.tar.xz"
	echo $TARBALL
	echo "tar cfJ ${TARBALL} /home/"
elif [ "${1}x" == "var" ]; then
	TARBALL="/tmp/varetc_${DATE}_${HOSTNAME}.tar.xz"
	echo $TARBALL
	echo "tar cfJ ${TARBALL} --exclude /var/run --exclude /var/tmp /var /etc"
else
	TARBALL="/tmp/full_${DATE}_${HOSTNAME}.tar.xz"
	echo "tar ${TARBALL} --exclude /dev --exclude /tmp --exclude /proc --exclude /sys --exclude-vcs --exclude-backups --exclude /media --exclude /mnt --exclude /var/tmp --exclude /run --exclude /var/run /"
fi

if [ ${HOSTNAME} == "jupiter.dataking.us" ]; then
	echo "ssh ${TARBALL} 192.168.100.5:/opt/backups/${HOSTNAME}/"
fi
