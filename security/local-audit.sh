#!/usr/bin/bash

#######################################################################
#
#   Error Codes:
#       1:      Not run with sufficient privileges.  Run as root or use sudo.
#       2:      Unable to collect distribution from /etc/lsb-release or /etc/os-release.  (TODO)
#       3:      Distribution not recognized.  Unable to update system.  (TODO)
#	4:	Unable to determine OS_FAMILY.  This most likely means I haven't ecountered this OS string yet.
#	5:	There was an error with the redhat useradd command, but it doesn't say what is wrong.
#	6:	There was an error with the debian useradd command, but it doesn't say what it wrong.
#
#######################################################################
#function RUNTIMEERRORi() {

#}
### This function attempts to get the distribution name.
### This should be expanded to discover multiple distros.
function get_distribution() {
    DISTRIB=""
    if [[ -e /etc/lsb-release ]]; then
        DISTRIB=$(grep "DISTRIB_ID=" /etc/lsb-release | cut -d= -f2 | sed -e 's/"//g')
    elif [[ -e /etc/os-release ]]; then
        DISTRIB=$(grep -E "\bID=" /etc/os-release | cut -d= -f2 | sed -e 's/"//g')
    else
        echo "Unable to determine distribution from /etc/lsb-release or /etc/os-release."
    fi
}

### Checks to see if a package is installed.
function is_installed() {
	PKG=$1
	FOUND=$(dpkg --get-selections | grep "\binstall\b" | cut -f1 | cut -d: -f1 | grep "^${PKG}$")

	if [[ "${FOUND}x" == "x" ]]; then
		echo "FALSE"
	else
		echo "TRUE"
	fi
}

# This script *reasonably* checks the same things the ansible audits check.
echo "====================### 000 SCRIPT PREP ###===================="
echo -n "  Checking user id...."
if [[ $(id -u) -ne 0 ]]; then
    echo ""
    echo "Because this script accesses files and directories in other users' home"
    echo "directories, as well as potential system and security-related files, it"
    echo "is necessary to run this script with elevated privileges (sudo)."
    exit 1
fi
echo "done."
declare -i TOTAL_CHECKS=10
declare -i CHECKS_RUN=0
declare -i SKIPPED_CHECKS=0
# set the DISTRIB variable to the name of the distribution: ubuntu, debian, redhat, rocky, etc.
# TODO: Should also probably try to classify OS family. An OS Family of 'Debian' would include, Ubuntu, Linux Mint Kali, etc.
get_distribution

#Endeavor to derive the os family from DISTRIB
OS_FAMILIES_LOOKUP=( [ubuntu]="debian" [debian]="debian" [rocky]="redhat" [rhel]="redhat" [centos]="redhat" )
echo "INFO::  DISTRIB = ${DISTRIB}"
echo "INFO::  OS_FAMILIES_LOOKUP = ${OS_FAMILIES_LOOKUP}"
OS_FAMILY=${OS_FAMILIES_LOOKUP[$DISTRIB]}
echo "INFO::  OS_FAMILY = ${OS_FAMILY}"


echo "====================### 001 USERS CHECKS ###===================="
echo "  Ensure relevant groups exist..."
echo "  --------------------"
for G in admin charlie pi sudo ubuntu; do
    if getent group "${G}" >/dev/null; then
        echo "    Group '${G}' exists."
    else
        echo "    Group '${G}' does NOT exist."
        echo "      Adding group '${G}'...."
        groupadd ${G}
    fi
done
CHECKS_RUN+=1

echo "  --------------------"
echo "  Ensure the relevant user accounts exist..."
echo "  --------------------"
for U in charlie pi ubuntu; do
    if id -u ${U} >/dev/null 2>&1; then
        echo "    User '${U}' exists."
    else   
        echo "    User '${U}' does not exist."
        echo "    Adding user '${U}' with primary group of 'sudo'..."
	if [[ $OS_FAMILY == "redhat" ]]; then
		useradd -m -k /etc/skel -g sudo -G wheel,${U} -s /bin/bash -c "${U}" ${U}
		#useradd -m -k /etc/skel -g sudo -G wheel,test -s /bin/bash -c "This is a test" test
		if [ $? -ne 0 ]; then
			echo "ERROR :::: THERE WAS AN UNSPECIFIED ERROR!!!"
			echo "ERROR :::: (redhat) (useradd)"
			exit 5
		fi
	elif [[ $OS_FAMILY == "debian" ]]; then
        	useradd -m -k /etc/skel -g sudo -s /bin/bash -C "${U}"
		if [ $? -ne 0 ]; then
			echo "ERROR :::: THERE WAS AN UNSPECIFIED ERROR!!!"
			echo "ERROR :::: (debian) (useradd)"
			exit 6
		fi
	else
		echo "    DISTRIB: ${DISTRIB}"
		echo "    OS_FAMILY: ${OS_FAMILY}"
		echo "UNABLE TO DETERMINE OS_FAMILY.  ${OS_FAMILY} is unrecognized."
		exit 4
	fi
	echo "    Adding groups to user..."
	if [[ $OS_FAMILY == "redhat" ]]; then
		usermod -G admin,${U} ${U}
		if [ $? -ne 0 ]; then
			echo "ERROR :::: There was an unspecified error."
			echo "ERROR :::: (redhat) (usermod)"
			exit 7
		fi
	elif [[ $OS_FAMILY == "debian" ]]; then
		usermod -g admin,${U} ${U}
		if [ $? -ne 0 ]; then
			echo "ERROR :::: There was an unspecieid error."
			echo "ERROR :::: (debian) (usermod)"
			exit 8
		fi
	else
		echo "ERROR :::: Unrecognized OS_FAMILY=($OS_FAMILY)"
		exit 9
	fi
    fi
done
CHECKS_RUN+=1

echo "  --------------------"
echo "  Check if each user has ssh keys..."
echo "  --------------------"
for U in charlie pi ubuntu; do
    if [[ -e /home/${U}/.ssh/id_rsa.pub ]]; then
        echo "    User ${U} has a public key."
    else
        echo "Could not find public key for user '${U}', in the default path."
    fi
    if [[ -e /home/${U}/.ssh/id_rsa ]]; then
        echo "    User ${U} has a private key."
    else
        echo "Could not find public key for user '${U}', in the default path."
        echo "    Creating SSH keys for ${U}..."
        if [[ ! -e /home/${U}/.ssh ]]; then
            mkdir -p /home/${U}/.ssh
        fi
        sudo -u ${U} ssh-keygen -t rsa -b 4096 -N "" -f /home/${U}/.ssh/id_rsa
    fi
done
CHECKS_RUN+=1

echo "  --------------------"
echo "  Check if each user has .bashrc..."
echo "  --------------------"
for U in charlie pi ubuntu; do
    if [[ -e /home/${U}/.bashrc && ! -z /home/${U}/.bashrc ]]; then
        echo "    User ${U} has a .bashrc that is not 0 bytes."
    else
        echo "    .bashrc not located for ${U}....copying."
        cp files/.bashrc /home/${U}/
    fi
done
CHECKS_RUN+=1

echo "  --------------------"
echo "  Check if each user has .bash_aliases..."
echo "  --------------------"
for U in charlie pi ubuntu; do
    if [[ -e /home/${U}/.bash_aliases && ! -z /home/${U}/.bash_aliases ]]; then
        echo "    User ${U} has a .bash_aliases that is not 0 bytes."
    else
        echo "    .bash_aliases not located for ${U}....copying."
        cp files/.bash_aliases /home/${U}/
    fi
done
CHECKS_RUNS+=1

echo "  --------------------"
echo "  Check if each user has .profile..."
echo "  --------------------"
for U in charlie pi ubuntu; do
    if [[ -e /home/${U}/.profile && ! -z /home/${U}/.profile ]]; then
        echo "    User ${U} has a .profile that is not 0 bytes."
    else
        echo "    .bashrc not located for ${U}....copying."
        cp files/.profile /home/${U}/
    fi
done
CHECKS_RUN+=1

echo "====================### 002 UPDATE SYSTEM ###===================="
SKIP_REF="skip"
echo "  --------------------"
echo "This next section will attempt to update the system cache and any"
echo "packages that require updating.  If you want to skip this step, "
echo "type 'SKIP'."
echo "  --------------------"
echo -n "Type SKIP to skip or ENTER to continue with the update: "
read SKIP_UPDATE
if [[ ${SKIP_UPDATE,,} == ${SKIP_REF,,} ]]; then
    echo "    #### Skipping system update. ####"
    SKIPPED_CHECKS+=1
else
    echo "    Starting system update."
    if [[ ${OS_FAMILY,,} == "debian" ]]; then
        apt-get update -qq
        if [[ $(apt list --upgradable 2>&1 /dev/null) ]]; then
            echo "TRUE RC: $?"
        else
            echo "FALSE RC: $?"
        fi
        echo "    System has been updated."
        if [[ -e /var/run/reboot-required ]]; then
            REBOOT_REQUIRED=0
            echo "    A reboot is required after the completion of this script."
        fi
    elif [[ ${OS_FAMILY,,} == "redhat" ]]; then
	    yum makecache
	    if [ $? -ne 0 ]; then
		    echo "ERROR :::: Return code not 0i ($?)"
		    echo "ERROR :::: (redhat) (yum makecache)"
		    exit 10
	    fi
    else
        echo "Unrecognized distribution. |${DISTRIB}|"
        exit 3
    fi
    CHECKS_RUN+=1
fi

echo "====================### 003 VERIFY PACKAGES ###===================="
echo "  --------------------"
echo "  Checking desired packages are installed."
echo "  --------------------"
if [[ ${DISTRIB,,} == "ubuntu" || ${DISTRIB,,} == "debian" ]]; then
    for PKG in aide apt-show-versions chkrootkit clamav clamav-freshclam cpanminus debsums fail2ban git htop libcrack2 net-tools ntopng pipx python3-pip rkhunter screen ufw vim wget; do
        if [[ $(is_installed ${PKG}) == "TRUE" ]]; then
            echo "      Installed: ${PKG}"
        else
            echo "      NOT Installed: ${PKG}"
        fi
    done
else
    echo "Unknown package manager.  Unable to check installed packages."
fi
CHECKS_RUN+=1

echo "  -------------------"
echo "  Ensure ssh is enabled at boot time."
echo "  -------------------"
if [[ $(systemctl status ssh | grep "Active" | cut -d" " -f7) == "active" ]]; then
    echo "    ssh.service is currently running."
else
    echo "    ssh.service is NOT running."
fi
if [[ $(systemctl status ssh | grep "Loaded" | cut -d" " -f9 | sed -e 's/;//g') == "enabled" ]]; then
    echo "    ssh.service is enabled."
else
    echo "    ssh.service is NOT enabled."
fi
CHECKS_RUN+=1

echo "====================### AUDIT COMPLETE ###===================="
echo "TOTAL_CHECKS: ${TOTAL_CHECKS}"
echo "CHECKS_RUN: ${CHECKS_RUN}"
echo "SKIPPED_CHECKS: ${SKIPPED_CHECKS}"
echo "====================### AUDIT COMPLETE ###===================="
echo "                        AUDIT COMPLETE"
echo "====================### AUDIT COMPLETE ###====================" 

if [[ $REBOOT_REQUIRED ]]; then
    echo "  A reboot has been indicated after updating the system.  Would you like to reboot now?"
    read ANS
    if [[ ${ANS,,} == "y" || ${ANS,,} == "yes" ]]; then
        reboot
    fi
fi
