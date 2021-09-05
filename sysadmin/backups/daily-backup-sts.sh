#!/bin/bash

DATE=$(date '+%Y-%m-%d')
tar cvpfJ /tmp/shermantheshermanator.com-${DATE}.tar.xz --directory /tmp/ /var/www/shermantheshermanator.com/
if [ $? -eq 0 ]; then
	#scp -P 2222 /root/www.dataking.us-${DATE}.tar.xz root@vhome.dataking.us:/media/sf_backups/
	aws s3 cp /tmp/shermantheshermanator.com-${DATE}.tar.xz s3://dk-website-backups/shermantheshermanator.com/
	if [ $? -eq 0 ]; then
		rm -f /tmp/shermantheshermanator.com-${DATE}.tar.xz
	else
		echo "There was a problem with the transfer."
	fi
else
	echo "There was a problem with the backup."
fi
