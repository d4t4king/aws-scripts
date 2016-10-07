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
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue --exclude /var/www/html/mirror --exclude /var/www/html/isos --exclude /var/nullmailer/queue /var /etc
	elif [ "${HOSTNAME}" == "mercury.dataking.us" ]; then
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue --exclude /var/www/html/mirror --exclude /var/www/html/isos --exclude /var/cache/apt/archive --exclude /var/nullmailer/queue /var /etc
	else
		tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue --exclude /var/cache/apt/archive --exclude /var/nullmailer/queue /var /etc
	fi
else
	# Skip any VMs for the full backup.  We should have gotten them in the "home" backup.
	TARBALL="/tmp/full_${DATE}_${HOSTNAME}.tar.xz"
	if [ "${HOSTNAME}" == "luna" ]; then
		tar cvfJ ${TARBALL} --exclude /dev --exclude /tmp --exclude /proc --exclude /sys --exclude-vcs --exclude-backups --exclude /media --exclude /mnt --exclude /var/tmp --exclude /run --exclude /var/run --exclude "swe*" --exclude "otw*" --exclude "*.iso" --exclude "*/VirtualBox VMs" --exclude "*/vmware/*" --exclude "*.ova" --exclude /s --exclude /var/www/html/mirror --exclude /var/nullmailer/queue /
	elif [ "${HOSTNAME}" == "oortcloud.dataking.us" ]; then
		tar cvfJ ${TARBALL} --exclude /dev --exclude /tmp --exclude /proc --exclude /sys --exclude-vcs --exclude-backups --exclude /media --exclude /mnt --exclude /var/tmp --exclude /run --exclude /var/run --exclude "swe*" --exclude "otw*" --exclude "*.iso" --exclude "*/VirtualBox VMs" --exclude "*/vmware/*" --exclude "*.ova" --exclude /s --exclude /var/www/html/mirror --exclude /opt --exclude /var/nullmailer/queue /
	else
		tar cvfJ ${TARBALL} --exclude /dev --exclude /tmp --exclude /proc --exclude /sys --exclude-vcs --exclude-backups --exclude /media --exclude /mnt --exclude /var/tmp --exclude /run --exclude /var/run --exclude "swe*" --exclude "otw*" --exclude "*.iso" --exclude "*/VirtualBox VMs" --exclude "*/vmware/*" --exclude "*.ova" --exclude /var/cache/apt/archives --exclude /var/nullmailer/queue /
	fi
fi

if [ $HOSTNAME == "mercury.dataking.us" ]; then
	/usr/local/bin/pd3000 "Backup complete." "Copying to storage..."
fi
if [ "${HOSTNAME}" == "jupiter.dataking.us" -o "${HOSTNAME}" == "neptune.dataking.us" ]; then
	scp ${TARBALL} 192.168.100.5:/opt/backups/${HOSTNAME}/
elif [ "${HOSTNAME}" == "luna" ]; then
	scp ${TARBALL} oortcloud:/opt/backups/${HOSTNAME}.dataking.us/
elif [ "${HOSTNAME}" == "oortcloud.dataking.us" ]; then
	cp -vf ${TARBALL} /opt/backups/${HOSTNAME}/
else
	scp ${TARBALL} 192.168.1.61:/opt/backups/${HOSTNAME}/
fi
if [ $? == 0 ]; then
	rm -vf ${TARBALL}
else 
	echo "Error during copy.  Skipping remove."
fi
if [ $HOSTNAME == "mercury.dataking.us" ]; then
	/usr/local/bin/pd3000 "$1 backup on " "${HOSTNAME} compelte."
fi
