#!/bin/sh

# Copyright
# Vladislav V. Prodan <github.com/click0>
# https://support.od.ua
# 2018-2023

# original script by Greg:
# https://gregoryo.wordpress.com/2015/04/15/mfsbsd-tweaks-to-help-automation/

# tested

set -x

# Dependence:
# mkisofs

#	defined variables

url="http://mfsbsd.vx.sk/files/iso/10/amd64/"
file_iso="mfsbsd-se-12.2-RELEASE-amd64.iso"
dir_tftp="/var/tftp/images/mfsbsd/"
dir_tmp="/tmp/repack-mfsbsd"
file_iso_prefix="new" # extension of output image
# date format 180122 + random 6 symbol [a-zA-Z0-9]
file_iso_prefix="$(date '+%y%m%d')$(env LC_CTYPE=C LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c6)"

url_snapshot="http://ftp.ua.freebsd.org/pub/FreeBSD/snapshots/amd64/12.4-PRERELEASE/"
snapshot_file_list="base.txz lib32.txz kernel.txz BUILDDATE REVISION SRCBRANCH"

dir_root_file_list="/tmp/repack-mfsbsd/root_file"
mfsbsd_dir_key=""
mfsbsd_root_password=""
mfsbsd_root_hash=""

#iface_manual=YES
#manual_gw='defaultrouter="1.1.1.1"'			# gateway IP
#manual_iface='ifconfig_em0="inet 1.1.1.2/24"'	# interface IP
#nameserver="8.8.8.8"

# we must be on freebsd
what_os_am_i="$(uname)"
if [ "$what_os_am_i" != "FreeBSD" ]; then
	echo "Please run on FreeBSD only"
	exit
fi

#	Mount the ISO, clone its contents, mount the root filesystem

[ -d "${dir_tmp}" ] && { rmdir -rf ${dir_tmp}; }
mkdir -p ${dir_tmp} ${dir_tmp}/dist ${dir_tmp}/mfsiso.mnt ${dir_tmp}/isocontents
cd ${dir_tmp} || exit
[ ! -e dist/${file_iso} ] && (cp ${dir_tftp}/${file_iso} ${dir_tmp}/dist/ || fetch -o ${dir_tmp}/dist $url/${file_iso})
iso_image=dist/${file_iso}
mfs_iso_dev="$(mdconfig -a -t vnode -f ${iso_image})"
mount_cd9660 /dev/"${mfs_iso_dev}" mfsiso.mnt || exit
cp -Rp mfsiso.mnt/* isocontents/
gunzip isocontents/mfsroot.gz

mkdir -p mfsroot.mnt
mfs_root_dev="$(mdconfig -a -t vnode -f isocontents/mfsroot)"
mount /dev/"${mfs_root_dev}" mfsroot.mnt || exit

#	Make desired modifications

[ -n "$nameserver" ] && echo mfsbsd.nameservers="$nameserver" >>isocontents/boot/loader.conf

if [ -n "${dir_root_file_list}" ] || [ "${iface_manual}" = "yes" ] || [ "${iface_manual}" = "YES" ]; then
	mkdir -p mfsroot
	tar -xf mfsroot.mnt/root.txz -C mfsroot/
fi

if [ -n "${url_snapshot}" ] && [ -n "${snapshot_file_list}" ]; then
	(
		cd isocontents || return
		cd "$(ls | grep amd64 | head -1)" || return
		rm -f *.txz
		for file in ${snapshot_file_list}; do
			env FETCH_RETRY=5 fetch -4 "${url_snapshot}"/$file
		done
	)
fi

if [ -n "${dir_root_file_list}" ] && [ -e "${dir_root_file_list}" ]; then
	cp -Rp "${dir_root_file_list}"/* mfsroot/rw/root/
fi

if [ "${iface_manual}" = "1" ] || [ "${iface_manual}" = "yes" ] || [ "${iface_manual}" = "YES" ]; then
	cat <<EOF >>isocontents/boot/loader.conf
${manual_gw}
${manual_iface}
EOF
sed -i '' -r '/^mfsbsd.autodhcp/s/^mfsbsd.autodhcp/#mfsbsd.autodhcp/g' isocontents/boot/loader.conf
fi

if [ -n "${dir_root_file_list}" ]; then
	rm -f mfsroot.mnt/root.txz
	echo "Compression works more than 4 minutes!"
	tar -c -C mfsroot -f - rw | xz -v -c > mfsroot.mnt/root.txz
fi

#	Unmount and repackage the image to a new ISO[1]

umount mfsroot.mnt
[ -e new_image.iso ] && rm new_image.iso
mdconfig -d -u "$(echo ${mfs_root_dev} | sed 's/md//')"
gzip isocontents/mfsroot
boot_sector=$(isoinfo -d -i ${iso_image} | grep Bootoff | awk '{print $3}')
dd if=${iso_image} bs=2048 count=1 skip=${boot_sector} of=isocontents/boot.img
mkisofs -J -R -no-emul-boot -boot-load-size 4 -b boot.img -o new_image.iso isocontents/

mkdir -p ${dir_tftp}
file_iso_out="$(echo ${file_iso} | cut -d . -f 1-2)"-"${file_iso_prefix}".iso

[ -e ${dir_tftp}/${file_iso_out} ] && rm ${dir_tftp}/${file_iso_out}
mv -i new_image.iso ${dir_tftp}/${file_iso_out}
md5 ${dir_tftp}/${file_iso_out} >>${dir_tftp}/${file_iso_out}.sums.txt
sha256 ${dir_tftp}/${file_iso_out} >>${dir_tftp}/${file_iso_out}.sums.txt

#	Clean up

umount mfsiso.mnt
mdconfig -d -u "$(echo ${mfs_iso_dev} | sed 's/md//')"
rmdir mfsiso.mnt
rmdir mfsroot.mnt
rm -rf isocontents
[ -n "${dir_root_file_list}" ] || [ "${iface_manual}" = "yes" ] || [ "${iface_manual}" = "YES" ] && rm -rf mfsroot

# rmdir -rf ${dir_tmp}
