#!/bin/sh

url1=http://mfsbsd.vx.sk/files/iso/11/amd64/
file1=mfsbsd-se-11.1-RELEASE-amd64.iso
file1_md5=6722786b20e641ae4830a0594c37214c
dir1=/boot/images


install_debian() {

	apt-get -y install grub-imageboot

	#	sudo -s

	mkdir -p $dir1
	cd $dir1 || exit
	wget $url1/$file1
	md5sum $dir1/$file1 | grep ${file1_md5} && echo md5 OK || exit

	update-grub
	# not work!	#grub-set-default 2 

	sed -i'' -e 's/set default="0"/set default="2"/g' /boot/grub/grub.cfg
	echo reboot!

}

install_ubuntu() {

	install_debian

}


install_centos() {

	yum install grub-imageboot || exit
	install_debian

}

install_redhat() {

	install_centos
}


apt-get update
apt-get -y install lsb-release || yum install redhat-lsb-core


[ "$(lsb_release -is)" = "Debian" ] && { install_debian ; exit; }

[ "$(lsb_release -is)" = "Ubuntu" ] && { install_ubuntu ; exit; }

[ "$(lsb_release -is)" = "Centos" ] && { install_centos ; exit; }

[ "$(lsb_release -is)" = "RedHat" ] && { install_redhat ; exit; }

