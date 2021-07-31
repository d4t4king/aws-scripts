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
	sysctl "${KEY} = ${STATUS}"
	grep "${KEY}" /etc/sysctl.conf > /dev/null
	if [ $? == 1 ]; then
		#KEY=$(echo "${KEY}" | awk -F= '{ print $1 }')
		echo "${KEY} = ${STATUS}" >> /etc/sysctl.conf
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
		sed -i -e "s/\("${KEY}"\) \?= \?"${ONFF}"/\1 = "${STATUS}"/" /etc/sysctl.conf
	fi
#set +x
}

is_installed() {
	PKG=$1
	SILENT=$2
	FOUND=$(dpkg --get-selections | grep "\binstall\b" | cut -f1 | cut -d: -f1 | grep "^${PKG}$")

	if [[ "${FOUND}x" == "x" ]]; then
		echo "FALSE"
	else
		echo "TRUE"
	fi
}

if [ -e /etc/gentoo-release -a ! -z /etc/gentoo-release ]; then
	OS="gentoo"
elif [ -e /etc/debian_version -a ! -z /etc/debian_version ]; then
	OS="debian/ubuntu"
elif [ -e /etc/centos_version -a ! -z /etc/centos_version ]; then
	OS="centos/redhat"
else
	OS="unknown"
fi


if [ $(id -u) != 0 ]; then
	echo "This script must be run as root.\n";
fi

# check for the skip list/profile
if [ ! -d /etc/lynis ]; then
	echo -n "Global profile directory does not exist.  Creating..."
	mkdir /etc/lynis
	touch /etc/lynis/custom.prf
	echo "done."
else
	echo -n "Profile directory exists, checking file..."
	if [ -e /etc/lynis/custom.prf ]; then
		echo "exists."
	else
		touch /etc/lynis/custom.prf
		echo "created."
	fi
fi

#A=$(is_installed bash false)
#echo "${A} : $?"
#B=$(is_installed foobar false)
#echo "${B} : $?"

#exit 1

# some basic package configuration
if [[ $(is_installed php*) == "TRUE" ]]; then
	# php.ini's
	echo "Finding and replacing values in php.ini's..."
	for F in `find / -type f -name "php.ini"`; do
		echo -n "${F}" && sed -i -e 's/\(expose_php = \)On/\1Off/' -e 's/\(allow_url_fopen = \)On/\1Off/' $F
	done
else
	echo "PHP is not installed."
fi

if [[ $(is_installed postfix) == "TRUE" ]]; then
	# postfix banner obfuscation
	echo "Updating postfix config..."
	case $OS in 
		"debian/ubuntu")
			if [ -e /etc/postfix/main.cf -a ! -z /etc/postfix/main.cf ]; then
				sed -i -e 's/\(smtpd_banner = \$myhostname ESMTP\) $mail_name (Ubuntu)/\1/' /etc/postfix/main.cf
				/etc/init.d/postfix reload
			else
				echo "Postfix config file not found."
			fi
			;;
		"redhat/centos")
			if [ -e /etc/postfix/main.cf -a ! -z /etc/postfix/main.cf ]; then
				#smtpd_banner = $myhostname ESMTP $mail_name
				sed -i -e 's/#\?\(smtpd_banner = \$myhostname ESMTP\) $mail_name/\1/' /etc/postfix/main.cf
				systemctl restart postfix
			else
				echo "Postfix config file not found."
			fi
			;;
		"gentoo")
			if [ -e /etc/postfix/main.cf -a ! -z /etc/postfix/main.cf ]; then
				sed -i -e '#\(smtpd_banner = $myhostname ESMTP\)/\1/' /etc/postfix/main.cf
				/etc/init.d/postfix reload
			else
				echo "Postfix config file not found."
			fi
			;;
		*)
			;;
	esac
else
	echo "postfix is not installed."
fi

# Given some testing, this has a tendency to break stuff.
# default umasks
#echo "Setting default umasks..."
#case $OS in
#	"debian/ubuntu")
#		sed -i -e 's/\(UMASK.*\?\)022/\1027/' /etc/login.defs
#		sed -i -e 's/\(umask\) 022/\1 027/' /etc/init.d/rc
#		;;
#	"gentoo")
#		sed -i -e 's/^\(umask\) [0-9][0-9][0-9]/\1 027/' /etc/profile
#		sed -i -e 's/^\(UMASK\)\s*[0-9][0-9][0-9]/\1	027/' /etc/login.defs
#		;;
#	*)
#		;;
#esac

# update first
echo "Updating system and checking for hardening tools..."
case $OS in 
	"debian/ubuntu")
		apt-get update && apt-get upgrade -y
		# install some required packages
		#apt-get install libpam-cracklib clamav aide apt-show-versions rkhunter acct -y
		#apt-get install libpam-cracklib apt-show-versions -y
		# 4/12/2017 -- 
		# 7/19/2021 -- 
		for P in usbguard unattended-upgrades iptables-persistent libpam-cracklib apt-show-versions libpam-tmpdir libpam-usb debian-goodies debsecan debsums rkhunter acct arpwatch aide cpanminus; do
			if [[ $(is_installed ${P}) == "TRUE" ]]; then 
				echo "${P} already installed" 
			else 
				apt-get install ${P} -y 
			fi
		done
		;;
	"redhat/centos")
		yum update -y
		yum install arpwatch aide rkhunter -y
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
sysctl_update "kernel.kptr_restrict" "2"
sysctl_update "net.ipv4.conf.all.rp_filter" "1"
sysctl_update "net.ipv4.conf.default" "1"
sysctl_update "net.ipv4.conf.all.accept_redirects" "0"
sysctl_update "net.ipv4.conf.default.accept_redirects" "0"
sysctl_update "net.ipv4.conf.all.accept_redirects" "0"
sysctl_update "net.ipv4.conf.all.log_martians" "1"
sysctl_update "net.ipv4.conf.default.log_martians" "1"
sysctl_update "net.ipv4.conf.all.log_martians" "1"
sysctl_update "net.ipv4.conf.all.send_redirects" "0"
sysctl_update "net.ipv4.conf.default.accept_source_route" "0"
sysctl_update "net.ipv4.tcp_syncookies" "1"
sysctl_update "net.ipv4.tcp_timestamps" "0"
sysctl_update "net.ipv6.conf.all.accept_redirects" "0"
sysctl_update "net.ipv6.conf.default.accept_redirects" "0"

echo -n "Adding keywords to banner files..."
grep "access authorized legal" /etc/issue > /dev/null
if [ ! $? -eq 0 ]; then
	echo "access authorized legal monitor owner policy policies private prohibited restricted this unauthorized" >> /etc/issue
fi
grep "access authorized legal" /etc/issue.net > /dev/null
if [ ! $? -eq 0 ]; then
	echo "access authorized legal monitor owner policy policies private prohibited restricted this unauthorized" >> /etc/issue.net
fi
echo "done."

if [ -e /etc/modprobe.d/blacklist-firewire.conf -a ! -z /etc/modprobe.d/blacklist-firewire.conf ]; then
	grep -E "(ohci1394|sbp2|dv1394|raw1394|video1394|firewire-ohci|firewire-sbp2)" /etc/modprobe.d/blacklist-firewire.conf > /dev/null 2>&1
	if [ $? == 1 ]; then		# not found
		echo "Disabling firewire..."
		echo "blacklist ohci1394" >> /etc/modprobe.d/blacklist-firewire.conf
		echo "blacklist sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
		echo "blacklist dv1394" >> /etc/modprobe.d/blacklist-firewire.conf
		echo "blacklist raw1394" >> /etc/modprobe.d/blacklist-firewire.conf
		echo "blacklist video1394" >> /etc/modprobe.d/blacklist-firewire.conf
		echo "blacklist firewire-ohci" >> /etc/modprobe.d/blacklist-firewire.conf
		echo "blacklist firewire-sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
	else
		echo "Some or all firewaire strings found."
		echo "Firewaire may already be discabled.  Check manually to be sure."
	fi
elif [ ! -e /etc/modprobe.d ]; then
	echo "Creating /etc/modprobe.d..."
	mkdir /etc/modprobe.d
	echo "Disabling firewire..."
	echo "blacklist ohci1394" > /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist dv1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist raw1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist video1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist firewire-ohci" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist firewire-sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
elif [ -e /etc/modprobe.d -a ! -e /etc/modprobe.d/blacklist-firewire.conf ]; then
	echo "blacklist ohci1394" > /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist dv1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist raw1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist video1394" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist firewire-ohci" >> /etc/modprobe.d/blacklist-firewire.conf
	echo "blacklist firewire-sbp2" >> /etc/modprobe.d/blacklist-firewire.conf
else
	echo "/etc/modprobe.d/blacklist-firewire.conf exists.  Firewire may already be disabled.  Check manually to be sure."
fi

if [ -e /etc/modprobe.conf -a ! -z /etc/modprobe.conf ]; then
	grep "install usb-storage /bin/true" /etc/modprobe.conf > /dev/null
	if [ ! $? -eq 0 ]; then
		echo "Disabling USB storage..."
		echo "install usb-storage /bin/true" >> /etc/modprobe.conf
	else
		echo "Looks like USB storage may already be disabled.  Check /etc/modprobe.conf manually to be sure."
	fi
else
	echo "Creating /etc/modprobe.conf..."
	touch /etc/modprobe.conf
	echo "Disabling USB storage..."
	echo "install usb-storage /bin/true" >> /etc/modprobe.conf
fi

# Disable unnecessary/antiquated protocols.
for P in dccp sctp tipc rds; do
	echo "install ${P} /bin/true" >> /etc/modprobe.conf
done

# Disable and secure the CUPS daemon
if [[ $OS == "debian/ubuntu" ]]; then
	systemctl stop cups
	systemctl disable cups
	chmod 0600 /etc/cups*
fi

# Secure SSHD configusation
if [ -e /etc/ssh ]; then
	if [ -e /etc/ssh/sshd_config -a ! -z /etc/ssh/sshd_config ]; then
		echo -n "Modding sshd_config..."
		sed -i -e 's/#\?\(AllowTcpForwarding\) yes/\1 no/' /etc/ssh/sshd_config
		sed -i -e 's/#\?\(AllowAgentForwarding\) yes/\1 no/' /etc/ssh/sshd_config
		sed -i -e 's/#\?\(MaxAuthTries\) 6/\1 2/' /etc/ssh/sshd_config
		sed -i -e 's/#\?\(MaxSessions\) 10/\1 2/' /etc/ssh/sshd_config
		sed -i -e 's/#\?\(ClientAliveCountMax\) 3/\1 2/' /etc/ssh/sshd_config
		sed -i -e 's/#\?\(Compression\) yes/\1 no/' /etc/ssh/sshd_config
		echo "done."
	else
		echo "Looke like sshd_config does not exist or is zero (0) bytes.  Is sshd installed?"
	fi
else
	echo "It doesn't look like openssh-server is installed.  Or the config file is in an unexpected location."
fi

echo "Setting permissions on files...."
$ Files 0600
for F in /etc/crontab /etc/ssh/sshd_config /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly /etc/cups/cupsd.conf; do
	CURRENT=$(ls -l ${F} | awk '{ print $1 }')
	if [[ $CURRENT == "rw-------" ]]; then
		echo "Strict permissions on ${F}"
	else
		echo -n "Setting permissions on ${F}...."
		chmod 0600 ${F}
		echo "done."
	fi
done

for D in /etc/cron.d /etc/cups /etc/cupshelpers; do
	CURRENT=$(ls -l ${D} | awk '{ print $1 }')
	if [[ CURRENT == "rwx------" ]]; then
		echo "Strict permissions on ${D}"
	else
		echo -n "Setting permissions on ${D}...."
		chmod 0600 ${D}
		echo "done."
	fi
done

	

echo "Script done."

