#!/bin/sh

# Copyright
# Vladislav V. Prodan <github.com/click0>
# https://support.od.ua
# 2022


# source:
# https://forums.freebsd.org/threads/installing-freebsd-in-hetzner.85399/post-575112

dir_ram_disk="/tmp/ramdisk"
dir_ram_disk_size="150m"
url_img="https://myb.convectix.com/DL/mfsbsd-13.1.img"
disk=sda

mkdir -p ${dir_ram_disk}
chmod 777 ${dir_ram_disk}
mount -t tmpfs -o size=${dir_ram_disk_size} myramdisk ${dir_ram_disk}

cd ${dir_ram_disk} && wget ${url_img} &&\
 	 dd conv=fsync if=${dir_ram_disk}/"${url_img##*/}" of=/dev/${disk} &&\
 	 echo b > /proc/sysrq-trigger

