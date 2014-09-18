#!/bin/bash

# steps to harden AWS according to lynis-1.6.1
# certain tests, e.g. GRUB passwords, simply wom't
# be implemented and are ignored in the charlie.prf
# lynis profile.

sysctl_update() {
#set -x
	# accepts 2 options:
	# 	sysctl key to be changed ($1)
	# 	status ($2 -- on or off)
	KEY=$1; STATUS=$2;
	sysctl ${KEY}=${STATUS}
	grep "${KEY}" /etc/sysctl.conf > /dev/null
	if [ $? == 1 ]; then
		#KEY=$(echo "${KEY}" | awk -F= '{ print $1 }')
		echo "${KEY}=${STATUS}" >> /etc/sysctl.conf
	else 
		sed -i -e "s/\(${KEY}\) \?= \?/\1=${STATUS}/" /etc/sysctl.conf
	fi
#set +x
}


if [ $(id -u) != 0 ]; then
	echo "This script must be run as root.\n";
fi

# some basic package configuration
# php.ini's
for F in `find / -type f -name "php.ini"`; do
	echo -n "${F}" && sed -i -e 's/\(expose_php = \)On/\1Off/' -e 's/\(allow_url_fopen = \)On/\1Off/' $F
	#echo -n "${F}" && sed -e 's/\(allow_url_fopen = \)On/\1Off/' $F
done
# postfix banner obfuscation
sed -i -e 's/\(smtpd_banner = \$myhostname ESMTP\) $mail_name (Ubuntu)/\1/' /etc/postfix/main.cf
/etc/init.d/postfix reload
# default umasks
sed -i -e 's/\(UMASK.*\?\)022/\1027/' /etc/login.defs
sed -i -e 's/\(umask\) 022/\1 027/' /etc/init.d/rc

# update first
apt-get update && apt-get upgrade -y
# install some required packages
apt-get install libpam-cracklib clamav aide apt-show-versions rkhunter -y

# sysctl options
echo "# Additional hardening settings, based on Lynis audit." >> /etc/sysctl.conf
sysctl_update "net.ipv6.conf.default.accept_redirects" "0"
sysctl_update "net.ipv4.conf.all.accept_redirects" "0"
sysctl_update "net.ipv4.conf.all.log_martians" "1"
sysctl_update "net.ipv4.conf.all.send_redirects" "0"
sysctl_update "net.ipv6.conf.all.accept_redirects" "0"
sysctl_update "net.ipv6.conf.default.accept_redirects" "0"
