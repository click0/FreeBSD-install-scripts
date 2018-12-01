#!/bin/sh

url1=http://mfsbsd.vx.sk/files/iso/11/amd64
url2=http://otrada.od.ua/pub
file1=mfsbsd-se-11.0-RELEASE-amd64.iso

case ${file1} in
	mfsbsd-se-11.0-RELEASE-amd64.iso)	file1_md5=4e5d61dcf87d948f7a832f51062a1fbc ;;
	mfsbsd-se-11.1-RELEASE-amd64.iso)	file1_md5=6722786b20e641ae4830a0594c37214c ;;
	mfsbsd-se-11.2-RELEASE-amd64.iso)	file1_md5=f272b36b946d2e0b82666bc01bc7c6a9 ;;
	?) echo "Variable \${file1_md5} not found!" ;;
esac

dir1=/boot/images

network_settings() {

	ip=$(ip addr show | grep "inet\b" | grep -v "\blo" | awk '{print $2}' |\
    egrep -v "^(10|127\.0|192\.168|172\.16)\." | cut -d/ -f1 | head -1)
	ip=${ip:-"127.0.0.1"}

	ip_default=$(ip route | grep default | awk '{print $3;}' | head -1)
	ip_mask=${ip_mask:-"255.255.255.0"}
	ip_mask_short=${ip_mask_short:-"24"}

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

	cat << EOF >> /boot/grub/grub.cfg

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
    set kFreeBSD.mfsbsd.hostname="YOURHOSTNAME"
	# set kFreeBSD.mfsbsd.autodhcp="YES"
	set kFreeBSD.mfsbsd.autodhcp="NO"
	set kFreeBSD.mfsbsd.interfaces="vtnet0 lo0"
#	set kFreeBSD.mfsbsd.ifconfig_vtnet0="inet $ip netmask ${ip_mask}"
	set kFreeBSD.mfsbsd.ifconfig_vtnet0="inet $ip/24"
	set kFreeBSD.mfsbsd.defaultrouter="${ip_default}"
	set kFreeBSD.mfsbsd.nameservers="8.8.8.8 1.1.1.1"
	set kFreeBSD.mfsbsd.ifconfig_lo0="DHCP"
}

EOF

	sed -i'' -e 's/set default="0"/set default="3"/g' /boot/grub/grub.cfg

	echo reboot!

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


apt-get update || yum update
apt-get -y install lsb-release || yum install redhat-lsb-core


[ "$(lsb_release -is)" = "Debian" ] && { install_debian ; exit 1; }

[ "$(lsb_release -is)" = "Ubuntu" ] && { install_ubuntu ; exit 1; }

[ "$(lsb_release -is)" = "Centos" ] && { install_centos ; exit 1; }

[ "$(lsb_release -is)" = "RedHat" ] && { install_redhat ; exit 1; }
