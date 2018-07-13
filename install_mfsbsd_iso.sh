#!/bin/sh

url1=http://mfsbsd.vx.sk/files/iso/11/amd64
url2=http://otrada.od.ua/pub
file1=mfsbsd-se-11.0-RELEASE-amd64.iso
file1_md5=4e5d61dcf87d948f7a832f51062a1fbc

dir1=/boot/images

main() {

	#	sudo -s

	mkdir -p $dir1
	cd $dir1 || exit
	wget $url2/$file1 || wget $url1/$file1 || ( echo "ISO image not found"; exit; )
	md5sum $dir1/$file1 | grep ${file1_md5} && echo md5 OK || exit

	update-grub
	# not work!	#grub-set-default 2

	sed -i'' -e 's/set default="0"/set default="2"/g' /boot/grub/grub.cfg
	echo reboot!

}

install_debian() {

	apt-get -y install grub-imageboot || exit
	main

}

install_ubuntu() {

	install_debian

}


install_centos() {

	yum install grub-imageboot || exit
	main

}

install_redhat() {

	install_centos
}


apt-get update || yum update
apt-get -y install lsb-release || yum install redhat-lsb-core


[ "$(lsb_release -is)" = "Debian" ] && { install_debian ; exit; }

[ "$(lsb_release -is)" = "Ubuntu" ] && { install_ubuntu ; exit; }

[ "$(lsb_release -is)" = "Centos" ] && { install_centos ; exit; }

[ "$(lsb_release -is)" = "RedHat" ] && { install_redhat ; exit; }

