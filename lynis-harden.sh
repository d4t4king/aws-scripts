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
		case ${STATUS} in
			1)
				ONFF=0
				;;
			0)
				ONFF=1
				;;
			*)
				echo "Unexpected status. (${STATUS})"
				;;
		esac
		sed -i -e "s/\("${KEY}"\) \?= \?"${ONFF}"/\1="${STATUS}"/" /etc/sysctl.conf
	fi
#set +x
}

if [ -e /etc/gentoo-release -a ! -z /etc/gentoo-release ]; then
	OS="gentoo"
elif [ -e /etc/debian_version -a ! -z /etc/debian_version ]; then
	OS="debian/ubuntu"
else
	OS="unknown"
fi


if [ $(id -u) != 0 ]; then
	echo "This script must be run as root.\n";
fi

# some basic package configuration
# php.ini's
echo "Finding and replacing values in php.ini's..."
for F in `find / -type f -name "php.ini"`; do
	echo -n "${F}" && sed -i -e 's/\(expose_php = \)On/\1Off/' -e 's/\(allow_url_fopen = \)On/\1Off/' $F
done
# postfix banner obfuscation
echo "Updating postfix config..."
case $OS in 
	"debian/ubuntu")
		sed -i -e 's/\(smtpd_banner = \$myhostname ESMTP\) $mail_name (Ubuntu)/\1/' /etc/postfix/main.cf
		;;
	"gentoo")
		sed -i -e '#\(smtpd_banner = $myhostname ESMTP\)/\1/' /etc/postfix/main.cf
		;;
	*)
	;;
esac
/etc/init.d/postfix reload

# default umasks
echo "Setting default umasks..."
case $OS in
	"debian/ubuntu")
		sed -i -e 's/\(UMASK.*\?\)022/\1027/' /etc/login.defs
		sed -i -e 's/\(umask\) 022/\1 027/' /etc/init.d/rc
		;;
	"gentoo")
		sed -i -e 's/^\(umask\) [0-9][0-9][0-9]/\1 027/' /etc/profile
		sed -i -e 's/^\(UMASK\)\s*[0-9][0-9][0-9]/\1	027/' /etc/login.defs
		;;
	*)
		;;
esac

# update first
echo "Updating system and checking for hardening tools..."
case $OS in 
	"debian/ubuntu")
		apt-get update && apt-get upgrade -y
		# install some required packages
		apt-get install libpam-cracklib clamav aide apt-show-versions rkhunter acct -y
		;;
	"gentoo")
		eix-sync
		emerge -uDNav --with-bdeps=y world
		#emerge -av libpam-cracklib clamav aide rkhunter acct
		# go one by one and check if they're installed first
		equery l cracklib > /dev/null
		EXIT_STATUS=$?
		if [ $EXIT_STATUS = 1 ]; then
			# not installed
			emerge -av cracklib
		else
			echo "cracklib installed..."
		fi
		equery l clamav >/dev/null
		EXIT_STATUS=$?
		if [ $EXIT_STATUS = 1 ]; then
			# not installed
			emerge -av clamav
		else 
			echo "clamav installed..."
		fi
		equery l aide > /dev/null
		EXIT_STATUS=$?
		if [ $EXIT_STATUS = 1 ]; then
			emerge -av aide
		else
			echo "aide installed..."
		fi
		equery l rkhunter > /dev/null
		EXIT_STATUS=$?
		if [ $EXIT_STATUS = 1 ] ; then
			emerge -av rkhunter
		else
			echo "rkhunter installed..."
		fi
		equery l sys-process/acct > /dev/null
		EXIT_STATUS=$?
		if [ $EXIT_STATUS = 1 ]; then
			emerge -av sys-process/acct
		else 
			echo "acct installed..."
		fi
		;;
	*)
		;;
esac

# sysctl options
echo "Setting sysctl options..."
echo "# Additional hardening settings, based on Lynis audit." >> /etc/sysctl.conf
sysctl_update "kernel.core_uses_pid" "1"
sysctl_update "kernel.sysrq" "0"
sysctl_update "net.ipv4.conf.all.rp_filter" "1"
sysctl_update "net.ipv4.conf.default.accept_redirects" "0"
sysctl_update "net.ipv6.conf.default.accept_redirects" "0"
sysctl_update "net.ipv4.conf.all.accept_redirects" "0"
sysctl_update "net.ipv4.conf.all.log_martians" "1"
sysctl_update "net.ipv4.conf.default.log_martians" "1"
sysctl_update "net.ipv4.conf.all.log_martians" "1"
sysctl_update "net.ipv4.conf.all.send_redirects" "0"
sysctl_update "net.ipv6.conf.default.accept_redirects" "0"
sysctl_update "net.ipv6.conf.all.accept_redirects" "0"
sysctl_update "net.ipv4.conf.default.accept_source_route" "0"
sysctl_update "net.ipv4.tcp_syncookies" "1"
sysctl_update "net.ipv4.tcp_timestamps" "0"

echo "Adding keywords to banner files..."
grep "access authorized legal" /etc/issue > /dev/null
if [ ! $? -eq 0 ]; then
	echo "access authorized legal monitor owner policy policies private prohibited restricted this unauthorized" >> /etc/issue
fi
grep "access authorized legal" /etc/issue.net > /dev/null
if [ ! $? -eq 0 ]; then
	echo "access authorized legal monitor owner policy policies private prohibited restricted this unauthorized" >> /etc/issue.net
fi

if [ -e /etc/modprobe.d/blacklist-firewire.conf -a ! -z /etc/modprobe.d/blacklist-firewire.conf ]; then
	echo "Disabling firewire..."
	echo "blacklist ohci1394" > /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist dv1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist raw1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist video1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist firewire-ohci" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist firewire-sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
fi

grep "install usb-storage /bin/true" /etc/modprobe.conf > /dev/null
if [ ! $? -eq 0 ]; then
	echo "Disabling USB storage..."
	echo "install usb-storage /bin/true" >> /etc/modprobe.conf
fi

echo "Script done."

