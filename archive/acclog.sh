#!/bin/bash

for F in `ls -1 /var/log/nginx/access.log*`; do
	if [ `basename $F | awk -F. '{ print $4 }'`=="gz" ]; then
		zcat $F >> /tmp/access_log.tmp
	else
		cat $F >> /tmp/access_log.tmp
	fi
done

cat /tmp/access_log.tmp | sort -u >> /tmp/access_log
chown www-data:www-data /tmp/access_log
rm -f /tmp/access_log.tmp
