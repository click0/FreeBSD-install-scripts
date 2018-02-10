#!/bin/sh

# Copyright Vladislav V. Prodan admin@support.od.ua
# 2018
# https://gregoryo.wordpress.com/2015/04/15/mfsbsd-tweaks-to-help-automation/

# tested

set -x

#	defined variables

url="http://mfsbsd.vx.sk/files/iso/10/amd64/"
iso_file="mfsbsd-se-10.2-RELEASE-amd64.iso"
dir_tftp="/var/tftp/images/mfsbsd/"
dir_tmp="/tmp/repack-mfsbsd"
ext_out="new"	# extension of output image
# date format 180122 + random 6 symbol a-zA-Z0-9
ext_out=$(date '+%y%m%d')$(env LC_CTYPE=C LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c6)

#iface_manual=YES
#manual_gw='defaultrouter="1.1.1.1"'			# gateway IP
#manual_iface='ifconfig_em0="inet 1.1.1.2/24"'	# interface IP
#nameserver="8.8.8.8"

#	Mount the ISO, clone its contents, mount the root filesystem

[ -d $dir_tmp ] && { rmdir -rf $dir_tmp ; }
mkdir -p $dir_tmp $dir_tmp/dist $dir_tmp/mfsiso.mnt $dir_tmp/isocontents
cd $dir_tmp
[ ! -e dist/$iso_file ] && cp $dir_tftp/$iso_file $dir_tmp/dist/ || fetch -o dist $url/$iso_file;
iso_image=dist/$iso_file
mfs_iso_dev=`mdconfig -a -t vnode -f $iso_image`
mount_cd9660 /dev/$mfs_iso_dev mfsiso.mnt  || exit
cp -Rp mfsiso.mnt/* isocontents/
gunzip isocontents/mfsroot.gz
mkdir -p mfsroot.mnt
mfs_root_dev=`mdconfig -a -t vnode -f isocontents/mfsroot`
mount /dev/$mfs_root_dev mfsroot.mnt || exit

#	Make desired modifications

[ -n "$nameserver" ] && echo "nameserver $nameserver" >> mfsroot.mnt/etc/resolv.conf ;

if [ "${iface_manual}" == "1" ] || [ "${iface_manual}" == "yes" ] || [ "${iface_manual}" == "YES" ];
		then
	cat << EOF >> mfsroot.mnt/etc/rc.conf
${manual_gw}
${manual_iface}
ifconfig_DEFAULT="SYNCDHCP"
EOF

	cat << EOF >> mfsroot.mnt/etc/rc.local
# fixed network setting
/bin/sh /root/interface.sh
EOF

	cat << EOF >> mfsroot.mnt/root/interface.sh
#!/bin/sh

iface=\$(ifconfig -l -u | sed -e 's/lo[0-9]//' -e 's/enc[0-9]//' -e 's/gif[0-9]//' -e 's/  / /g')

ifconfig `echo \$iface | awk '{ print \$1; }'` `grep ifconfig /etc/rc.conf | awk -F\" '{ print \$2;}' | head -1`

EOF

	chmod +x mfsroot.mnt/root/interface.sh

fi

#	Unmount and repackage the image to a new ISO[1]

umount mfsroot.mnt
[ -e new_image.iso ] && rm new_image.iso;
mdconfig -d -u `echo $mfs_root_dev | sed 's/md//'`
gzip isocontents/mfsroot
boot_sector=`isoinfo -d -i $iso_image | grep Bootoff | awk '{print $3}'`
dd if=$iso_image bs=2048 count=1 skip=$boot_sector of=isocontents/boot.img
mkisofs -J -R -no-emul-boot -boot-load-size 4 -b boot.img -o new_image.iso isocontents/

mkdir -p $dir_tftp
[ -e $dir_tftp/${iso_file}-${ext_out} ] && rm $dir_tftp/${iso_file}-${ext_out};
mv -i new_image.iso $dir_tftp/${iso_file}-${ext_out}
md5 		$dir_tftp/${iso_file}-${ext_out} >> $dir_tftp/${iso_file}-${ext_out}.sums.txt
sha256 		$dir_tftp/${iso_file}-${ext_out} >> $dir_tftp/${iso_file}-${ext_out}.sums.txt

#	Clean up

umount mfsiso.mnt
mdconfig -d -u `echo $mfs_iso_dev | sed 's/md//'`
rmdir mfsiso.mnt
rmdir mfsroot.mnt

# rmdir -rf $dir_tmp
