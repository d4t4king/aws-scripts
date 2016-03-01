#!/bin/bash

DATE=$(date "+%Y-%m-%d-%H-%M-%S")

echo $DATE

HOSTNAME=$(hostname -f)

echo $HOSTNAME

if [ "${1}x" == "homex" ]; then
	TARBALL="/tmp/home_${DATE}_${HOSTNAME}.tar.xz"
	echo $TARBALL
	tar cvfJ ${TARBALL} --exclude-backups --exclude "*.iso" /home/
elif [ "${1}x" == "varx" ]; then
	TARBALL="/tmp/varetc_${DATE}_${HOSTNAME}.tar.xz"
	echo $TARBALL
	if [ "${HOSTNAME}" == "mars" ]; then 
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue --exclude /var/www/localhost/htdocs/mirror --exclude /var/www/localhot/htdocs/isos /var /etc
	elif [ "${HOSTNAME}" == "mercury.dataking.us" ]; then
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue --exclude /var/www/html/mirror --exclude /var/www/html/isos /var /etc
	else
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue /var /etc
	fi
else
	TARBALL="/tmp/full_${DATE}_${HOSTNAME}.tar.xz"
	tar cvfJ ${TARBALL} --exclude /dev --exclude /tmp --exclude /proc --exclude /sys --exclude-vcs --exclude-backups --exclude /media --exclude /mnt --exclude /var/tmp --exclude /run --exclude /var/run --exclude "*.iso" /
fi

if [ "${HOSTNAME}" == "jupiter.dataking.us" -o "${HOSTNAME}" == "neptune.dataking.us" ]; then
	scp ${TARBALL} 192.168.100.5:/opt/backups/${HOSTNAME}/
elif [ "${HOSTNAME}" == "mars" ]; then
	scp ${TARBALL} oortcloud:/opt/backups/${HOSTNAME}.dataking.us/
else
	scp ${TARBALL} oortcloud:/opt/backups/${HOSTNAME}/
fi
