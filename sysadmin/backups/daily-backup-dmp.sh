#!/bin/bash

DATE=$(date '+%Y-%m-%d')
tar cvpfJ /tmp/www.diegominpin.com-${DATE}.tar.xz --exclude /var/www/diegominpin.com/gallery/resources/cache /var/www/diegominpin.com/ /root/img_backup/
if [ $? -eq 0 ]; then
	#scp -P 2222 /root/www.diegominpin.com-${DATE}.tar.xz root@vhome.dataking.us:/media/sf_backups/
	aws s3 cp /tmp/www.diegominpin.com-${DATE}.tar.xz s3://dk-website-backups/diegominpin.com/
	if [ $? -eq 0 ]; then
		rm -f /tmp/www.diegominpin.com-${DATE}.tar.xz
	else
		echo "There was a problem with the transfer."
	fi
else
	echo "There was a problem with the backup."
fi
