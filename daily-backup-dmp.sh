#!/bin/bash

DATE=$(date '+%Y-%m-%d')
tar cvpfJ /root/www.diegominpin.com-${DATE}.tar.xz --directory /root/ --exclude /usr/share/nginx/html/gallery/resources/cache --exclude /root/www.diegominpin.com/gallery/resources/cache/ /usr/share/nginx/html/ /root/www.diegominpin.com/ /etc/nginx/ /root/img_backup/
if [ $? -eq 0 ]; then
	#scp -P 2222 /root/www.diegominpin.com-${DATE}.tar.xz root@vhome.dataking.us:/media/sf_backups/
	aws s3 cp /root/www.diegominpin.com-${DATE}.tar.xz s3://dk-website-backups/diegominpin.com/
	if [ $? -eq 0 ]; then
		rm -f /root/www.diegominpin.com-${DATE}.tar.xz
	else
		echo "There was a problem with the transfer."
	fi
else
	echo "There was a problem with the backup."
fi
