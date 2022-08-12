#!/bin/sh
# Philipp Wuensche
# This script is considered beer ware (http://en.wikipedia.org/wiki/Beerware)
# DISCLAIMER: Use at your own risk! Always make backups, don't blame me if this renders your system unusable or you lose any data! 
# $Id$
#

ftphost='ftp.freebsd.org'

usage="Usage: create-zfsboot-gpt_livecd.sh -p <geom_provider> -s <swap_partition_size> -S <zfs_partition_size> -n <zpoolname> -m <zpool-raidmode> -d <distdir> -f <ftphost>"

exerr () { echo -e "$*" >&2 ; exit 1; }

while getopts p:s:S:n:f:m:d: arg
do case ${arg} in
  p) provider="$provider ${OPTARG}";;
  s) swap_partition_size=${OPTARG};;
  S) zfs_partition_size=${OPTARG};;
  n) poolname=${OPTARG};;
  f) ftphost=${OPTARG};;
  m) mode=${OPTARG};;
  d) distdir=${OPTARG};;
  ?) exerr ${usage};;
esac; done; shift $(( ${OPTIND} - 1 ))

if [ -z "$poolname" ] || [ -z "$provider" ] ; then
  exerr ${usage}
  exit
fi

if [ "$distdir" ]; then
  if [ ! -f "$distdir/base/install.sh" -o ! -f "$distdir/kernels/install.sh" ]; then
    echo "Sorry, no distribution files found in ${distdir}!"
    exit
  fi
fi

# count the number of providers
devcount=`echo ${provider} |wc -w`

# set our default zpool mirror-mode
if [ -z "$mode" ]; then
    if [ "$devcount" -gt "1" ]; then
        mode='mirror'
    else
        mode='stripe'
    fi
fi

# check the settings for the users that want to set the mode on their own
if [ "$devcount" -eq "1" -a "$mode" = "mirror" ]; then
    echo "A mirror needs at least two disks!"
    exit
fi
if [ "$devcount" -lt "3" -a "$mode" = "raidz" ]; then
    echo "Sorry, you need at least three disks for a zfs raidz!"
    exit
fi

check_size () {
  ref_disk_size=`gpart list $ref_disk | grep 'Mediasize' | awk '{print $2}'`
  if [ "${zfs_partition_size}" ]; then
    _zfs_partition_size=`echo "${zfs_partition_size}"|tr GMKBWX gmkbwx|sed -Ees:g:km:g -es:m:kk:g -es:k:"*2b":g -es:b:"*128w":g -es:w:"*4 ":g -e"s:(^|[^0-9])0x:\1\0X:g" -ey:x:"*":|bc |sed "s:\.[0-9]*$::g"`
  fi
  if [ "${swap_partition_size}" ]; then
    _swap_partition_size=`echo "${swap_partition_size}"|tr GMKBWX gmkbwx|sed -Ees:g:km:g -es:m:kk:g -es:k:"*2b":g -es:b:"*128w":g -es:w:"*4 ":g -e"s:(^|[^0-9])0x:\1\0X:g" -ey:x:"*":|bc |sed "s:\.[0-9]*$::g"`
  fi
  total_size=$((${_zfs_partition_size}+${_swap_partition_size}+162))
  if [ "${total_size}" -gt "${ref_disk_size}" ]; then
    echo "ERROR: The current settings for the partitions sizes will not fit onto your disk."
    exit
  else
    echo fix
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
    exit
  fi
  echo " -> $disk"
  dd if=/dev/zero of=/dev/$disk bs=512 count=79 > /dev/null 2>&1
  gpart create -s gpt $disk > /dev/null
done

echo
sleep 1

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
check_size

echo
echo "NOTICE: Using $ref_disk (smallest or only disk) as reference disk for calculation offsets"
echo
sleep 2

echo "Creating GPT boot partition on disks:"
for disk in $provider; do
  get_disk_labelname
  echo " ->  ${disk}"
  gpart add -s 128 -t freebsd-boot $disk > /dev/null
done

echo
sleep 2

if [ "$swap_partition_size" ]; then
  echo "Creating GPT swap partition on with size ${swap_partition_size} on disks: "
  for disk in $provider; do
    get_disk_labelname
    echo " ->  ${disk} (Label: ${label})"
    gpart add -s $swap_partition_size -t freebsd-swap -l swap-${label} ${disk} > /dev/null
  done
fi

echo
sleep 2

offset=`gpart show $ref_disk | grep '\- free \-' | awk '{print $1}'`
if [ -z "${zfs_partition_size}" ]; then
  size=`gpart show $ref_disk | grep '\- free \-' | awk '{print $2}'`
else
  size=${zfs_partition_size}
fi

echo "Creating GPT ZFS partition on with size ${size} on disks: "
for disk in $provider; do
  get_disk_labelname
  echo " ->  ${disk} (Label: ${label})"
  gpart add -b $offset -s $size -t freebsd-zfs -l system-${label} ${disk} > /dev/null
  labellist="${labellist} gpt/system-${label}"
done

echo
sleep 2

# Make first partition active so the BIOS boots from it
for disk in $provider; do
  get_disk_labelname
  echo 'a 1' | fdisk -f - $disk > /dev/null 2>&1
done

echo
sleep 2

kldload /mnt2/boot/kernel/opensolaris.ko
kldload /mnt2/boot/kernel/zfs.ko

# we need to create /boot/zfs so zpool.cache can be written.
mkdir /boot/zfs

# Create the pool and the rootfs

if [ "$mode" = "raidz" ]; then
  zpool create -f $poolname raidz ${labellist}
fi
if [ "$mode" = "mirror" ]; then
  zpool create -f $poolname mirror ${labellist}
fi
if [ "$mode" = "stripe" ]; then
  zpool create -f $poolname ${labellist}
fi

if [ `zpool list -H -o name $poolname` != "$poolname" ]; then
  echo "ERROR: Could not create zpool $poolname"
  exit
fi

sleep 2

echo "Setting checksum to fletcher4"
zfs set checksum=fletcher4 ${poolname}

rootzfs="$poolname/ROOT/$poolname"

zfs create -p $rootzfs
zfs set freebsd:boot-environment=1 $rootzfs

# Now we create some stuff we also would like to have in seperate filesystems
for filesystem in usr-src usr-obj usr-local tmp; do
   echo "Creating $poolname/$filesystem"
   zfs create $poolname/$filesystem
   if [ "$filesystem" = "tmp" ]; then
     chmod 1777 /$poolname/tmp
   fi
   zfs umount $poolname/$filesystem
   _filesystem=`echo $filesystem | sed s:-:\/:g`
   zfs set mountpoint=/${_filesystem} $poolname/${filesystem}
done

mkdir /$rootzfs/usr

zfs set mountpoint=/$rootzfs/usr/src $poolname/usr-src
zfs mount $poolname/usr-src

zfs set mountpoint=/$rootzfs/usr/obj $poolname/usr-obj
zfs mount $poolname/usr-obj

echo ####################################
if [ -z "$distdir" ]; then
    echo "Now installing base, ssys, slib and kernels via $ftphost. This may take a while, depending on your network connection."
    zfs create $poolname/installdata
    cd /$poolname/installdata
    
    if [ `pwd` != "/$poolname/installdata" ]; then
        echo "ERROR: Could not change directoy to /$poolname/installdata. Aborting."
        exit
    fi
    
    sleep 2
    arch=`uname -p`
    release=`uname -r`
    echo
    echo "Fetching FreeBSD ${release}-${arch}:"
    for pkg in base kernels; do
        mkdir /$poolname/installdata/${pkg}
        cd /$poolname/installdata/${pkg}
        echo " -> $pkg"
        ftp -V "$ftphost:pub/FreeBSD/releases/${arch}/${release}/${pkg}/*"
    done
    distdir="/$poolname/installdata"
else
    echo "Using distribution packages from $distdir"
fi

export DESTDIR=/$rootzfs/

echo
echo "Extracting base into $DESTDIR"
cd /$distdir/base ; cat base.?? | tar --unlink -xpzf - -C ${DESTDIR:-/}
echo "Extracting kernel into ${DESTDIR}boot"
cd /$distdir/kernels ; sh ./install.sh generic

cd /$rootzfs/boot ; cp -rp GENERIC/* /$rootzfs/boot/kernel/

if [ -z "$distdir" ]; then
    zfs destroy $poolname/installdata
fi

# fix usr/share/man/man8
rm /$rootzfs/usr/share/man/man8

echo
echo "Installing new bootcode on disks: "
for disk in $provider; do
  get_disk_labelname
  echo " ->  ${disk}"
  gpart bootcode -b /$rootzfs/boot/pmbr -p /$rootzfs/boot/gptzfsboot -i 1 $disk > /dev/null
done
echo

# We need to fix /usr/src so it is mounted correct when booting from ZFS
zfs umount $poolname/usr-src
zfs set mountpoint=/usr/src $poolname/usr-src

# We need to fix /usr/obj so it is mounted correct when booting from ZFS
zfs umount $poolname/usr-obj
zfs set mountpoint=/usr/obj $poolname/usr-obj

# Enable the new filesystem as zpool bootfs
zpool set bootfs=$rootzfs $poolname

# We still need to tell the kernel from where to mount its root-filesystem
echo 'zfs_load="YES"' >> /$rootzfs/boot/loader.conf
echo "vfs.root.mountfrom=\"zfs:$rootzfs\"" >> /$rootzfs/boot/loader.conf
echo 'zfs_enable="YES"' >> /$rootzfs/etc/rc.conf
touch /$rootzfs/etc/fstab

if [ "$swap_partition_size" ]; then
  echo "Adding swap partitions in fstab:"
  for disk in $provider; do
    get_disk_labelname
    echo " ->  /dev/gpt/swap-${label}"
    echo "/dev/gpt/swap-${label} none swap sw 0 0" >> /$rootzfs/etc/fstab
  done
fi
echo

# Copy the zpool.cache to the new filesystem
cp /boot/zfs/zpool.cache /$rootzfs/boot/zfs/zpool.cache

sleep 5

echo "Please reboot the system from the harddisk(s), remove the FreeBSD CD from you cdrom!"
