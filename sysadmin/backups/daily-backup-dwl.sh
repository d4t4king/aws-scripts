#!/bin/bash

DATE=$(date '+%Y-%m-%d')
tar cvpfJ /root/dnswhitelist.info-${DATE}.tar.xz --directory /root/ /usr/share/nginx/html/ /root/dnswhitelist.info/ /etc/nginx/
if [ $? -eq 0 ]; then
	# old method
	#scp -P 2222 /root/dnswhitelist.info-${DATE}.tar.xz root@dataking.us:/media/sf_backups/
	aws s3 cp /root/dnswhitelist.info-${DATE}.tar.xz s3://dk-website-backups/dnswhitelist.info/
	if [ $? -eq 0 ]; then
		rm -f /root/dnswhitelist.info-${DATE}.tar.xz
	else
		echo "There was a problem with the transfer."
	fi
else
	echo "There was a problem with the backup."
fi
