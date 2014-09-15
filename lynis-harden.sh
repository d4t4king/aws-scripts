#!/bin/bash

# steps to harden AWS according to lynis-1.6.1
# certain tests, e.g. GRUB passwords, simply wom't
# be implemented and are ignored in the charlie.prf
# lynis profile.

if [ $(id -u) != 0 ]; then
	echo "This script must be run as root.\n";
fi

# some basic package configuration
 for F in `find / -type f -name "php.ini"`; do
	echo -n "${F}" && sed -i -e 's/\(expose_php = \)On/\1Off/' -e 's/\(allow_url_fopen = \)On/\1Off/' $F
	#echo -n "${F}" && sed -e 's/\(allow_url_fopen = \)On/\1Off/' $F
done
sed -i -e 's/\(smtpd_banner = \$myhostname ESMTP\) $mail_name (Ubuntu)/\1/' /etc/postfix/main.cf
sed -i -e 's/\(UMASK.*\?\)022/\1027/' /etc/login.defs
sed -i -e 's/\(umask\) 022/\1 027/' /etc/init.d/rc

# install some required packages
apt-get install libpam-cracklib clamav aide apt-show-versions -s
