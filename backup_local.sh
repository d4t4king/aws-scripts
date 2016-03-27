#!/bin/bash

DATE=$(date "+%Y-%m-%d-%H-%M-%S")

echo $DATE

HOSTNAME=$(hostname -f)

echo $HOSTNAME
if [ $HOSTNAME == "mercury.dataking.us" ]; then
	/usr/local/bin/pd3000 "Starting $1 backup..."
fi
if [ "${1}x" == "homex" ]; then
	TARBALL="/tmp/home_${DATE}_${HOSTNAME}.tar.xz"
	echo $TARBALL
	tar cvfJ ${TARBALL} --exclude-backups --exclude "*.iso" /home/
elif [ "${1}x" == "varx" ]; then
	TARBALL="/tmp/varetc_${DATE}_${HOSTNAME}.tar.xz"
	echo $TARBALL
	if [ "${HOSTNAME}" == "luna" ]; then 
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue --exclude /var/www/html/mirror --exclude /var/www/html/isos /var /etc
	elif [ "${HOSTNAME}" == "mercury.dataking.us" ]; then
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue --exclude /var/www/html/mirror --exclude /var/www/html/isos /var /etc
	else
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue /var /etc
	fi
else
	# Skip any VMs for the full backup.  We should have gotten them in the "home" backup.
	TARBALL="/tmp/full_${DATE}_${HOSTNAME}.tar.xz"
	if [ "${HOSTNAME}" == "luna" ]; then
		tar cvfJ ${TARBALL} --exclude /dev --exclude /tmp --exclude /proc --exclude /sys --exclude-vcs --exclude-backups --exclude /media --exclude /mnt --exclude /var/tmp --exclude /run --exclude /var/run --exclude "swe*" --exclude "otw*" --exclude "*.iso" --exclude "*/VirtualBox VMs" --exclude "*/vmware/*" --exclude "*.ova" --exclude /s --exclude /var/cache/apt/archives /
	else
		tar cvfJ ${TARBALL} --exclude /dev --exclude /tmp --exclude /proc --exclude /sys --exclude-vcs --exclude-backups --exclude /media --exclude /mnt --exclude /var/tmp --exclude /run --exclude /var/run --exclude "swe*" --exclude "otw*" --exclude "*.iso" --exclude "*/VirtualBox VMs" --exclude "*/vmware/*" --exclude "*.ova" --exclude /var/cache/apt/archives /
	fi
fi

if [ $HOSTNAME == "mercury.dataking.us" ]; then
	/usr/local/bin/pd3000 "Backup complete." "Copying to storage..."
fi
if [ "${HOSTNAME}" == "jupiter.dataking.us" -o "${HOSTNAME}" == "neptune.dataking.us" ]; then
	scp ${TARBALL} 192.168.100.5:/opt/backups/${HOSTNAME}/
elif [ "${HOSTNAME}" == "luna" ]; then
	scp ${TARBALL} oortcloud:/opt/backups/${HOSTNAME}.dataking.us/
else
	scp ${TARBALL} oortcloud:/opt/backups/${HOSTNAME}/
fi
rm -vf ${TARBALL}
if [ $HOSTNAME == "mercury.dataking.us" ]; then
	/usr/local/bin/pd3000 "$1 backup on " "${HOSTNAME} compelte."
fi
