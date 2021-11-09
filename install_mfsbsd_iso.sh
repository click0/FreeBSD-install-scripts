#!/bin/sh

# Current Version: 1.01

# Copyright
# Vladislav V. Prodan <github.com/click0>
# https://support.od.ua
# 2018-2021

# syntax
# script_name.sh 13.0 <hostname> fxp0 250

mfsbsd_version_default="12.2" # or 12
hostname_default="YOURHOSTNAME"
iface_list_default="vtnet0 em0"
need_free_space_default="250"	# in megabytes!


mfsbsd_version=${1:-${mfsbsd_version_default}}

if [ "${mfsbsd_version}" == "${mfsbsd_version%.*}" ]; then
  mfsbsd_version=${mfsbsd_version}".0"
fi

url1=http://mfsbsd.vx.sk/files/iso/${mfsbsd_version%.*}/amd64
url2=http://otrada.od.ua/pub
file1=mfsbsd-se-${mfsbsd_version}-RELEASE-amd64.iso

hostname=${2:-${hostname_default}}
iface_list=${3:-${iface_list_default}}
need_free_space=${4:-${need_free_space_default}}

case ${file1} in
	mfsbsd-se-11.0-RELEASE-amd64.iso)	file1_md5=4e5d61dcf87d948f7a832f51062a1fbc ;;
	mfsbsd-se-11.1-RELEASE-amd64.iso)	file1_md5=6722786b20e641ae4830a0594c37214c ;;
	mfsbsd-se-11.2-RELEASE-amd64.iso)	file1_md5=f272b36b946d2e0b82666bc01bc7c6a9 ;;
	mfsbsd-se-12.0-RELEASE-amd64.iso)	file1_md5=e44a55d9682dcd250433313ebc32f4ca ;;
	mfsbsd-se-12.2-RELEASE-amd64.iso)	file1_md5=556d9194563377c404c935749651ef71 ;;
	mfsbsd-se-13.0-RELEASE-amd64.iso)	file1_md5=06cae0e6e18cc05bf913b519fd1de130 ;;
	?) echo "Variable \${file1_md5} not found!" ;;
esac

dir1=/boot/images

network_settings() {

	ip=$(ip addr show | grep "inet\b" | grep -v "\blo" | awk '{print $2}' |\
		egrep -v "^(10|127\.0|192\.168|172\.16)\." | cut -d/ -f1 | head -1)
	ip=${ip:-"127.0.0.1"}
	ipv6=$(ip addr show | grep "inet6\b" | grep -v "\bscope host" | awk '{print $2}' | egrep -v '^::1|^fe'| head -1)
	ip_mask_short=$(ip addr show | grep "inet\b" | grep -v "\blo" | awk '{print $2}' |\
		egrep -v "^(10|127\.0|192\.168|172\.16)\." | cut -d/ -f2 | head -1)

	ip_default=$(ip route | grep default | awk '{print $3;}' | head -1)
	ip_mask=${ip_mask:-"255.255.255.0"}
	ip_mask_short=${ip_mask_short:-"24"}
	[ "${ip_mask_short}" == "32" ] && ip_mask_short=22;
	ipv6_default=$(ip -6 route | grep default | awk '{print $3;}' | head -1)
	iface_mac=$(ip link show | grep ether | head -1 | awk '{print $2;}')

}

check_free_space_boot() {

	echo Проверяем свободное место на разделе /boot

	if grep -q /boot /proc/mounts; then
		if [ "$(df -m /boot | awk '/\// {print $4;}')" -le "${need_free_space}" ] ; then
			echo "No space in partition /boot!"
			exit 1;
		fi
	else
		if grep '/ ' /proc/mounts; then
			if [ "$(df -m / | awk '/\// {print $4;}')" -le "${need_free_space}" ] ; then
				echo "No space in partition / !"
				exit 1;
			fi
		fi
	fi

}

main() {

	#	sudo -s

	mkdir -p $dir1
	cd $dir1 || exit 1
	if [ ! -e "$file1" ]; then
		if ( ping -q -c3 otrada.od.ua  > /dev/null 2>&1 )
		then
			wget $url2/$file1 || wget $url1/$file1
		else
			wget $url1/$file1
		fi
	fi
	[ ! -e "$file1" ] && { echo "ISO image not found"; exit 1; }
	md5sum $dir1/$file1 | grep ${file1_md5} && echo md5 OK || exit 1;

	update-grub

	# inserting network options
	# http://zajtcev.org/other/freebsd/install-freebsd-to-ovh-with-mfsbsd.html

	network_settings

	file234=/boot/grub/grub.cfg
	cat << EOF >> ${file234}

menuentry "$file1" {
	set isofile=/boot/images/$file1
	# (hd0,1) here may need to be adjusted of course depending where the partition is
	loopback loop (hd0,1)\$isofile
	kfreebsd (loop)/boot/kernel/kernel.gz -v
	# kfreebsd_loadenv (loop)/boot/device.hints
	# kfreebsd_module (loop)/boot/kernel/geom_uzip.ko
	kfreebsd_module (loop)/boot/kernel/ahci.ko
	kfreebsd_module (loop)/mfsroot.gz type=mfs_root
	set kFreeBSD.vfs.root.mountfrom="ufs:/dev/md0"
	set kFreeBSD.mfsbsd.hostname="$hostname"
	# set kFreeBSD.mfsbsd.autodhcp="YES"
	set kFreeBSD.mfsbsd.autodhcp="NO"
#	set kFreeBSD.mfsbsd.interfaces="${iface_list} lo0"
#	for iface in ${iface_list}; do
#		echo set kFreeBSD.mfsbsd.ifconfig_$iface=\"inet $ip/${ip_mask_short}\"
#		echo set kFreeBSD.mfsbsd.ifconfig_$iface=\"inet6 $ipv6\"
#	done
	set kFreeBSD.mfsbsd.mac_interfaces="ext1"
	set kFreeBSD.mfsbsd.ifconfig_ext1_mac="${iface_mac}"
	set kFreeBSD.mfsbsd.ifconfig_ext1="inet $ip/${ip_mask_short}"
#	set kFreeBSD.mfsbsd.ifconfig_$iface="inet $ip/${ip_mask_short}"
	set kFreeBSD.mfsbsd.defaultrouter="${ip_default}"
	set kFreeBSD.mfsbsd.nameservers="8.8.8.8 1.1.1.1"
	set kFreeBSD.mfsbsd.ifconfig_lo0="DHCP"
#	set kFreeBSD.mfsbsd.ipv6_defaultrouter="${ipv6_default}"

}

EOF

#	sed -i'' -e 's/set default="0"/set default="3"/g' ${file234}
	menuentry=$(grep '^menuentry ' ${file234} | wc -l)
#	[ "$(lsb_release -is)" = "Debian" ] && { $(( $menuentry - 2)); }
	echo "set default=\"$menuentry\"" >> ${file234}

	echo reboot!
	check_free_space_boot

}

install_debian() {

	apt-get -y install grub-imageboot || exit 1;
	main

}

install_ubuntu() {

	install_debian

}


install_centos() {

	yum install grub-imageboot || exit 1
	main

}

install_redhat() {

	install_centos

}


check_free_space_boot

apt-get update || yum update
apt-get -y install lsb-release || yum install redhat-lsb-core


[ "$(lsb_release -is)" = "Debian" ] && { install_debian ; exit 1; }

[ "$(lsb_release -is)" = "Ubuntu" ] && { install_ubuntu ; exit 1; }

[ "$(lsb_release -is)" = "Centos" ] && { install_centos ; exit 1; }

[ "$(lsb_release -is)" = "RedHat" ] && { install_redhat ; exit 1; }
