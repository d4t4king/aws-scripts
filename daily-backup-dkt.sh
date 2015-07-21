#!/bin/bash

DATE=$(date '+%Y-%m-%d')
tar cvpfJ /root/www.dataking.technology-${DATE}.tar.xz --directory /root/ /usr/share/nginx/html/ /root/www.dataking.technology/
if [ $? -eq 0 ]; then
	scp -P 2222 /root/www.dataking.technology-${DATE}.tar.xz root@vhome.dataking.us:/media/sf_backups/
	if [ $? -eq 0 ]; then
		rm -f /root/www.dataking.technology-${DATE}.tar.xz
	else
		echo "There was a problem with the transfer."
	fi
else
	echo "There was a problem with the backup."
fi
