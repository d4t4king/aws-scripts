#!/bin/bash

DATE=$(date "+%Y-%m-%d-%H-%M-%S")

echo $DATE

HOSTNAME=$(hostname -f)

echo $HOSTNAME
if [ "${1}x" == "homex" ]; then
	TARBALL="/tmp/home_${HOSTNAME}_${DATE}.tar.xz"
	echo $TARBALL
	tar cvfJ ${TARBALL} --exclude-backups --exclude "*.iso" /home/
elif [ "${1}x" == "varx" ]; then
	TARBALL="/tmp/varetc_${HOSTNAME}_${DATE}.tar.xz"
	echo $TARBALL
	tar cvfJ ${TARBALL} --exclude-backups --exclude-vcs --exclude /var/run --exclude /var/tmp --exclude /var/spool/clientmqueue --exclude /var/cache/apt/archive /var /etc
else
	# Skip any VMs for the full backup.  We should have gotten them in the "home" backup.
	TARBALL="/tmp/full_${HOSTNAME}_${DATE}.tar.xz"
	tar cvfJ ${TARBALL} --exclude /dev --exclude /tmp --exclude /proc --exclude /sys --exclude-vcs --exclude-backups --exclude /media --exclude /mnt --exclude /var/tmp --exclude /run --exclude /var/run --exclude "*.iso" --exclude "*/VirtualBox VMs" --exclude "*/vmware/*" --exclude "*.ova" --exclude "/var/cache/apt/archives/*" /
fi

scp ${TARBALL} 172.16.100.183:/opt/backups/${HOSTNAME}/
if [ $? == 0 ]; then
	rm -vf ${TARBALL}
else
	echo "There was a problem copying the tarbal!"
fi
