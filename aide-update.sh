#!/bin/bash

if [[ $(id -u) != 0 ]]; then
	echo "Must be root."
	exit 1
fi

pushd /var/lib/aide
if [ -e "aide.conf.autogenerated" ];
	rm -fv aide.conf.autogenerated
	sed -i -e "s@CONFFILE=\"/var/lib/aide/aide.conf.autogenerated\"@CONFFILE=\"/etc/aide/aide.conf\"@" /etc/cron.daily/aide
fi

/usr/bin/aide -c /etc/aide/aide.conf -u 
cp -vf aide.db.new aide.db
for A in md5 sha1 sha256; 
do
	${A}sum aide.db > aide.db.${A}
done

