#!/bin/sh

# $Id: go11_4k.sh,v 1.3 2017/03/03 22:56:21 root Exp $
# original script by Philipp Wuensche at http://anonsvn.h3q.com/s/gpt-zfsroot.sh
# This script is considered beer ware (http://en.wikipedia.org/wiki/Beerware)
# modifyed with great help of gkontos from http://www.aisecure.net/2011/05/01/root-on-zfs-freebsd-current/
# by Olaf Klein - monkeytower internet agency http://www.monkeytower.net
#
# DISCLAIMER: Use at your own risk! Always make backups, don't blame me if this renders your system unusable or you lose any data!
#
# This only works/only tested with FreeBSD 9.0 rc2, you have been warned!
#
# Startup the FreeBSD livefs (i used memstick). Go into the Fixit console. and prepare:
# tcsh
# set autolist
# umount /tmp
# mdmfs -s 512M md1 /tmp
# ifconfig
# dhclient nfe0 (or whatever your NIC is)
# mkdir -p /tmp/bsdinstall_etc
# echo nameserver 10.0.0.1 >/etc/resolv.conf
# cd /tmp
# fetch http://www.monkeytower.net/go9.sh
# chmod +x go9.sh
#
# Execute the script with the following parameter:
#
# -p sets the geom provider to use, you can use multiple. Add a name for the GPT labels: -p ad4=black -p ad6=white
# -s sets the swap_partition_size to create, you can use m/M for megabyte or g/G for gigabyte
# -S sets the zfs_partition_size to create, you can use m/M for megabyte or g/G for gigabyte, default is all available size
# -n sets the name of the zpool to create
# -m sets the zpool raid-mode, stripe (only single disk), mirror (at least two disks) and raidz (at least three disks) or raid10 with at least 4 disks
# -d sets local directory to get distribution packages from
#
# You can use more than one device, creating a mirror. To specify more than one device, use multiple -p options.
# eg. go.sh -p ad0 -p ad1 -s 512m -n tank
#
#
# in case something goes wrong and you want to start over:
# zpool destroy tank
# might be a good idea (_before_ you give it another try).
#
# enjoy. Feedback welcome to ok@monkeytower.net
#
# regards.
# olaf.

set -x

txzfiles="/mfs"
#distdir=${txzfiles}"/distdir"
#ftphost="ftp://ftp6.ua.freebsd.org/pub/FreeBSD/snapshots/amd64/amd64/12.0-ALPHA10"
ftphost="ftp://ftp1.de.freebsd.org/pub/FreeBSD/releases/amd64/amd64/12.0-RC3"
#ftphost="ftp://ftp.de.freebsd.org/pub/FreeBSD/snapshots/amd64/amd64/12.1-STABLE"
#ftphost="ftp://ftp6.ua.freebsd.org/pub/FreeBSD/snapshots/amd64/amd64/11.1-PRERELEASE"
ftphost="ftp://ftp6.ua.freebsd.org/pub/FreeBSD/snapshots/amd64/amd64/12.1-STABLE"
ftp_mirror_list="ftp6.ua ftp1.fr ftp2.de"
filelist="base lib32 kernel doc"
memdisksize=310M
hostname=core.domain.com
iface="em0 em1 re0 igb0 vtnet0"
iface=$(ifconfig -l -u | sed -e 's/lo[0-9]*//' -e 's/enc[0-9]*//' -e 's/gif[0-9]*//' -e 's/  / /g')
zoneinfo="Europe/Kiev"
#iface_manual=YES
#manual_gw='defaultrouter="1.1.1.1"'			# gateway IP
#manual_iface='ifconfig_vtnet0="inet 1.1.1.2/24"'	# interface IP
#nameserver="8.8.8.8"							# single nameserver
#manual_gw_v6='ipv6_defaultrouter="2001:41d0:0005:1000::1"'			# gateway IP
#manual_iface_v6='ifconfig_vtnet0_ipv6=""2001:41d0:0005:1000:0000:0000:0000:abcd/64"'	# interface IP
url_ssh_key_list="http://otrada.od.ua http://support.org.ua/install/test123"

usage="Usage: go11.sh -p <geom_provider> -s <swap_partition_size> -S <zfs_partition_size> -n <zpoolname> -m <zpool-raidmode>"

exerr () { echo -e "$*" >&2 ; exit 1; }

while getopts p:s:S:n:f:m:d: arg
	do case ${arg} in
		p) provider="$provider ${OPTARG}";;
		s) swap_partition_size=${OPTARG};;
		S) zfs_partition_size=${OPTARG};;
		n) poolname=${OPTARG};;
		m) mode=${OPTARG};;
		?) exerr ${usage};;
	esac;
done;
shift $(( ${OPTIND} - 1 ))

if [ -z "$poolname" ] || [ -z "$provider" ] ; then
	exerr ${usage}
	exit
fi

sysctl kern.geom.label.gptid.enable=0
sysctl kern.geom.debugflags=16
sysctl vfs.zfs.min_auto_ashift=13

[ -n "$nameserver" ] && { mkdir -p /tmp/bsdinstall_etc ; echo 'nameserver $nameserver' > /tmp/bsdinstall_etc/resolv.conf ; }

[ ! -d $txzfiles ] && mkdir -p $txzfiles
[ ! -d $txzfiles ] && { txzfiles="/opt$txzfiles"; mkdir -p $txzfiles || exit 1; }
#mdmfs -s $memdisksize md10 $txzfiles
# check size /dev/md10
#if [ -e /dev/md10 ] && [ "`mdconfig -lv -u 10 | awk '{print $3;}'`" == "$memdisksize" ]; then
if [ -e /dev/md10 ]; then
	umount /dev/md10
	mdconfig -d -u 10
fi
if [ ! -e /dev/md10 ]; then
	mdconfig -a -s $memdisksize -u 10
	newfs -U /dev/md10
	mount /dev/md10 $txzfiles
fi


for file in ${filelist}; do (fetch -o $txzfiles/$file.txz $ftphost/$file.txz || exit 1); done

# count the number of providers
devcount=`echo ${provider} | xargs -n1 | sort -u | xargs | wc -w`

# set our default zpool mirror-mode
if [ -z "$mode" ]; then
	if [ "$devcount" -gt "1" ]; then
		mode='mirror'
	fi
	if [ "$devcount" -eq "4" ]; then
		mode='raid10'
	else
		mode='stripe'
	fi
fi
echo $mode

sleep 1

# check the settings for the users that want to set the mode on their own
if [ "$devcount" -eq "1" -a "$mode" = "mirror" ]; then
	echo "A mirror needs at least two disks!"
	exit
fi
if [ "$devcount" -lt "3" -a "$mode" = "raidz" ]; then
	echo "Sorry, you need at least three disks for a zfs raidz!"
	exit
fi
if [ "$devcount" -lt "4" -a "$mode" = "raid10" ]; then
	echo "Sorry, you need at least four disks for a raid10 equivalent szenario!"
	exit
fi
if [ "`expr $devcount % 2`" -ne "0" -a "$mode" = "raid10" ]; then
	echo "Sorry, you need an even number of disks for a raid10 equivalent szenario!"
	exit
fi

check_size () {
	ref_disk_size=`gpart list ${ref_disk} | grep 'Mediasize' | awk '{print $2}'`
	if [ "${zfs_partition_size}" ]; then
		_zfs_partition_size=`echo "${zfs_partition_size}"|awk '{print tolower($0)}'|sed -Ees:g:km:g -es:m:kk:g -es:k:"*2b":g -es:b:"*128w":g -es:w:"*4 ":g -e"s:(^|[^0-9])0x:\1\0X:g" -ey:x:"*":|bc |sed 's:\.[0-9]*$::g'`
	fi
	if [ "${swap_partition_size}" ]; then
		_swap_partition_size=`echo "${swap_partition_size}"|awk '{print tolower($0)}'|\
		sed -Ees:g:km:g -es:m:kk:g -es:k:"*2b":g -es:b:"*128w":g -es:w:"*4 ":g -e"s:(^|[^0-9])0x:\1\0X:g" -ey:x:"*":|\
 		bc |sed 's:\.[0-9]*$::g'`
	fi
	total_size=$((${_zfs_partition_size}+${_swap_partition_size}+162))
	if [ "${total_size}" -gt "${ref_disk_size}" ]; then
		echo "ERROR: The current settings for the partitions sizes will not fit onto your disk."
		exit 1
#	else
#		echo "unknown status!"
	fi
}

get_disk_labelname () {
	label=${disk##*=}
	disk=${disk%%=*}
}

echo "Creating GPT label on disks:"
for disk in $provider; do
	get_disk_labelname
	if [ ! -e "/dev/$disk" ]; then
		echo " -> ERROR: $disk does not exist"
		exit 1
	fi
	echo " -> $disk"
	# against PR 196102
	if ( gpart show /dev/$disk | egrep -v '=>| - free -|^$' ); then
		disk_index_list=$(gpart show /dev/$disk | egrep -v '=>| - free -|^$' | awk '{print $3;}' | sort -r)
		for disk_index in ${disk_index_list}; do
			gpart delete -i ${disk_index} /dev/$disk || exit 1
		done
	fi
	gpart destroy -F $disk > /dev/null
	gpart create -s gpt $disk > /dev/null
done

smallest_disk_size='0'
echo "Checking disks for size:"
for disk in $provider; do
	get_disk_labelname
	disk_size=`gpart show $disk | grep '\- free \-' | awk '{print $2}'`
	echo " -> $disk - total size $disk_size"
	if [ "$smallest_disk_size" -gt "$disk_size" ] || [ "$smallest_disk_size" -eq "0" ]; then
		smallest_disk_size=$disk_size
		ref_disk=$disk
	fi
done

# check if the size fits
swap_partition_size=${swap_partition_size:-"0"}
check_size

echo
echo "NOTICE: Using ${ref_disk} (smallest or only disk) as reference disk for calculation offsets"
echo
sleep 2

echo "Creating GPT boot partition on disks:"
counter=0
for disk in $provider; do
	get_disk_labelname
	echo " ->  ${disk}"
	gpart add -s 1024 -t freebsd-boot -a 8k -l boot-${counter} $disk > /dev/null
	counter=`expr $counter + 1`
done


if [ "${swap_partition_size}" ]; then
	echo "Creating GPT swap partition on with size ${swap_partition_size} on disks: "
	for disk in $provider; do
		get_disk_labelname
		echo " ->  ${disk} (Label: ${label})"
		gpart add -b 2048 -s ${swap_partition_size} -t freebsd-swap -a 8k -l swap-${label} ${disk} > /dev/null
		swapon /dev/gpt/swap-${label}
	done
fi

offset=`gpart show ${ref_disk} | grep '\- free \-' | tail -n 1 | awk '{print $1}'`
if [ -n "${zfs_partition_size}" ]; then
	size_string="-s ${zfs_partition_size}"
fi

echo "Creating GPT ZFS partition on with size ${zfs_partition_size} on disks: "
counter=0
for disk in $provider; do
	get_disk_labelname
	echo " ->  ${disk} (Label: ${label})"
	gpart add -t freebsd-zfs ${size_string} -a 8k -l system-${label} ${disk} > /dev/null

	if [ "$counter" -eq "0" -a "$mode" = "raid10" ]; then
		labellist="${labellist} mirror "
	fi
	counter=`expr $counter + 1`
	labellist="${labellist} gpt/system-${label}.nop"
	if [ "`expr $counter % 2`" -eq "0" -a "$devcount" -ne "$counter" -a "$mode" = "raid10" ]; then
		labellist="${labellist} mirror "
	fi
done

# show list GPT label
ls -l /dev/gpt/

# Make first partition active so the BIOS boots from it
for disk in $provider; do
	get_disk_labelname
	echo 'a 1' | fdisk -f - $disk > /dev/null 2>&1
# todo
# gpart set -a active $disk
# see https://forums.freebsd.org/threads/freebsd-gpt-uefi.42781/#post-238472
done

if ! `/sbin/kldstat -m zfs >/dev/null 2>/dev/null`; then
	/sbin/kldload zfs >/dev/null 2>/dev/null
fi
if ! `/sbin/kldstat -m g_nop >/dev/null 2>/dev/null`; then
	/sbin/kldload geom_nop.ko >/dev/null 2>/dev/null
fi


# we need to create /boot/zfs so zpool.cache can be written.
[ ! -d /boot/zfs ] && mkdir /boot/zfs

# create gnop
counter=0
for disk in $provider; do
	get_disk_labelname
	gnop create -S 8192 /dev/gpt/system-${label} > /dev/null
	counter=`expr $counter + 1`
done


zpool_option="-o altroot=/mnt -o cachefile=/tmp/zpool.cache"
# Create the pool and the rootfs

if [ "$mode" = "raidz" ]; then
	zpool create -f ${zpool_option} $poolname raidz ${labellist} || exit
fi
if [ "$mode" = "mirror" ]; then
	zpool create -f ${zpool_option} $poolname mirror ${labellist} || exit
fi
if [ "$mode" = "stripe" ]; then
	zpool create -f ${zpool_option} $poolname ${labellist} || exit
fi
if [ "$mode" = "raid10" ]; then
	zpool create -f ${zpool_option} $poolname ${labellist} || exit
fi

if [ `zpool list -H -o name $poolname` != "$poolname" ]; then
	echo "ERROR: Could not create zpool $poolname"
	exit
fi

zpool export $poolname

# destroy gnop
counter=0
for disk in $provider; do
	get_disk_labelname
	gnop destroy /dev/gpt/system-${label}.nop > /dev/null
	counter=`expr $counter + 1`
done
ls -l /dev/gpt/
sleep 15
zpool import ${zpool_option} $poolname
zpool status
gpart show

echo "Setting checksum to fletcher4"
zfs set checksum=fletcher4 $poolname
zfs set reservation=50M $poolname
zfs set compression=lz4 $poolname

zfs create -p $poolname
zfs set freebsd:boot-environment=1 $poolname
#zpool set bootfs=$poolname $poolname

# Now we create some stuff we also would like to have in separate filesystems

zfs set mountpoint=/mnt $poolname
zfs create $poolname/usr
#zfs create $poolname/usr/home
zfs create $poolname/var
zfs create -o compression=on    -o exec=on      -o setuid=off   $poolname/tmp
zfs create                      -o exec=on      -o setuid=off   $poolname/usr/ports
zfs create -o compression=off   -o exec=off     -o setuid=off   $poolname/usr/ports/distfiles
zfs create -o compression=off   -o exec=off     -o setuid=off   $poolname/usr/ports/packages
zfs create                      -o exec=on      -o setuid=off   $poolname/usr/src
zfs create                      -o exec=off     -o setuid=off   $poolname/usr/home
zfs create                      -o exec=off     -o setuid=off   $poolname/var/crash
zfs create                      -o exec=off     -o setuid=off   $poolname/var/db
zfs create                      -o exec=on      -o setuid=off   $poolname/var/db/pkg
zfs create                      -o exec=on      -o setuid=off   $poolname/var/ports
zfs create                      -o exec=off     -o setuid=off   $poolname/var/empty
zfs create                      -o exec=off     -o setuid=off   $poolname/var/log
zfs create -o compression=gzip  -o exec=off     -o setuid=off   $poolname/var/mail
zfs create                      -o exec=off     -o setuid=off   $poolname/var/run
zfs create                      -o exec=on      -o setuid=off   $poolname/var/tmp

zpool export $poolname
zpool import -o cachefile=/tmp/zpool.cache $poolname

zfs list

chmod 1777 /mnt/tmp
cd /mnt ; ln -s usr/home home
chmod 1777 /mnt/var/tmp

cd $txzfiles || exit 1
export DESTDIR=/mnt
for file in ${filelist}; do (tar --unlink -xpJf $file.txz -C ${DESTDIR:-/}); done

cp /tmp/zpool.cache /mnt/boot/zfs/zpool.cache

cat << EOF > /mnt/etc/rc.conf
zfs_enable="YES"
hostname="$hostname"
sshd_enable="YES"
sshd_flags="-oPort=22 -oCompression=yes -oPermitRootLogin=yes -oPasswordAuthentication=yes -oProtocol=2 -oUseDNS=no"
dumpdev="AUTO"
EOF


[ -n "$nameserver" ] && echo "nameserver $nameserver" >> /mnt/etc/resolv.conf ;

if [ "${iface_manual}" == "1" ] || [ "${iface_manual}" == "yes" ] || [ "${iface_manual}" == "YES" ];
	then
		cat << EOF >> /mnt/etc/rc.conf
${manual_gw}
${manual_iface}
ifconfig_DEFAULT="SYNCDHCP"

EOF
		for interface in ${iface}; do
			echo ifconfig_${interface}_ipv6=\"inet6 accept_rtadv\" >> /mnt/etc/rc.conf
		done
		echo ipv6_activate_all_interfaces=\"YES\" >> /mnt/etc/rc.conf
		echo " " >> /mnt/etc/rc.conf
		if [ -n "${manual_gw_v6}" ] && [ -n "${manual_iface_v6}" ]; then
			cat << EOF >> /mnt/etc/rc.conf
${manual_gw_v6}
${manual_iface_v6}

EOF
		fi
	else
		echo 'ifconfig_DEFAULT="SYNCDHCP"' >> /mnt/etc/rc.conf
		for interface in ${iface}; do
			echo ifconfig_$interface=\"DHCP\" >> /mnt/etc/rc.conf
			echo ifconfig_${interface}_ipv6=\"inet6 accept_rtadv\" >> /mnt/etc/rc.conf
		done
		echo ipv6_activate_all_interfaces=\"YES\" >> /mnt/etc/rc.conf
		echo " " >> /mnt/etc/rc.conf
fi

cat /mnt/etc/rc.conf

# put sshd_key
root_dir=/mnt/root/.ssh
mkdir ${root_dir} >> /dev/null
chmod 700 ${root_dir}
for url in ${url_ssh_key_list} ; do
	if ( ping -q -c3 $(echo $url | awk -F/ '{print $3;}') > /dev/null 2>&1 ); then
		for i in $(seq 1 9); do
			fetch -qo - $url/key$i.pub >> ${root_dir}/authorized_keys;
		done
		chmod 600 ${root_dir}/authorized_keys
		break;
	else
		echo "no ping to host $(echo $url | awk -F/ '{print $3;}')"
	fi
done

cat << EOF >> /mnt/boot/loader.conf
zfs_load="YES"
vfs.root.mountfrom="zfs:$poolname"
kern.geom.label.gptid.enable=0
kern.geom.label.disk_ident.enable=0
debug.acpi.disabled="thermal"

## enable vt text mode
#hw.vga.textmode=0

# for Linode Shell
boot_multicons="YES"
boot_serial="YES"
comconsole_speed="115200"
console="comconsole,vidconsole"

EOF

# 4) TTY for serial console
# deprecated after FreeBSD 12.0 or high
#cat << EOF >> /mnt/etc/ttys
#ttyu1 "/usr/libexec/getty std.9600" vt100 on secure
#EOF

# Options for tmux
echo "set-option -g history-limit 300000" >> /mnt/root/.tmux.conf

cat << EOF > /mnt/etc/fstab
#/etc/fstab

# Device		Mountpoint	FStype		Options	Dump	Pass#
EOF
if [ "$swap_partition_size" ]; then
	echo "Adding swap partitions in fstab:"
	for disk in $provider; do
		get_disk_labelname
		echo " ->  /dev/gpt/swap-${label}"
		echo -e "/dev/gpt/swap-${label}	none		swap	sw	0	0" >> /mnt/etc/fstab
	done
else
	touch /mnt/etc/fstab
fi

cat /mnt/etc/fstab

zfs set readonly=on $poolname/var/empty


echo
echo "Installing new bootcode on disks: "
for disk in $provider; do
	get_disk_labelname
	echo " ->  ${disk}"
	gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $disk
done

echo You\'ve just been chrooted into your fresh installation.
echo passwd root

cd /
chroot /mnt /bin/sh -c "hostname $hostname; make -C /etc/mail aliases; cp /usr/share/zoneinfo/$zoneinfo /etc/localtime;"
echo 'mfsroot123' | pw -V /mnt/etc usermod root -h 0
chroot /mnt /bin/sh -c "cd /; umount /dev"

zfs umount -a
zfs set mountpoint=legacy $poolname
zfs set mountpoint=/tmp $poolname/tmp
zfs set mountpoint=/usr $poolname/usr
zfs set mountpoint=/var $poolname/var

echo
echo "Please reboot the system from the harddisk(s), remove the FreeBSD media from you cdrom!"
