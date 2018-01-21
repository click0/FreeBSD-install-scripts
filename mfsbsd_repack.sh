#!/bin/sh

# https://gregoryo.wordpress.com/2015/04/15/mfsbsd-tweaks-to-help-automation/

# untested

# defined variables

url="http://mfsbsd.vx.sk/files/iso/10/amd64/"
iso_file="mfsbsd-10.1-RELEASE-amd64.iso"
dir_tftp="/tftpboot/images/mfsbsd10"

# Mount the ISO, clone its contents, mount the root filesystem

mkdir -p dist
fetch -o dist $url/$iso_file
iso_image=dist/$iso_file
mkdir -p mfsiso.mnt
mfs_iso_dev=`mdconfig -a -t vnode -f $iso_image`
mount_cd9660 /dev/$mfs_iso_dev mfsiso.mnt
mkdir -p isocontents
cp -Rp mfsiso.mnt/* isocontents/
gunzip isocontents/mfsroot.gz
mkdir -p mfsroot.mnt
mfs_root_dev=`mdconfig -a -t vnode -f isocontents/mfsroot`
mount /dev/$mfs_root_dev mfsroot.mnt

#	Make desired modifications

### autologin ###
sed -i '' -e 's/:ht:np:/:al=root:ht:np:/' mfsroot.mnt/etc/gettytab
### .login automatic operations ###
chmod g+w mfsroot.mnt/root/{,.login}
cat > mfsroot.mnt/root/prepare.sh << EOF
#!/bin/sh
puppet_server=puppet
mount_point=/mnt/deploy
ping_response=-1
while [ "0" != "\$ping_response" ]; do
  echo Waiting to let network connections settle ...
  sleep 1
  ping -qc 1 \$puppet_server > /dev/null
  ping_response=\$?
done
mkdir -p \$mount_point
mount \$puppet_server:/usr/exports/deploy \$mount_point
ln -sf \$mount_point/deploy.sh ./
EOF

chmod ug+x mfsroot.mnt/root/prepare.sh
chown root mfsroot.mnt/root/prepare.sh
cat > mfsroot.mnt/root/.login <<__eof_login__
/root/prepare.sh \$tty && /root/deploy.sh
__eof_login__
chmod g-w mfsroot.mnt/root/{,.login}
echo 'autoboot_delay="2"' >> isocontents/boot/loader.conf

#	Unmount and repackage the image to a new ISO[1]

umount mfsroot.mnt
mdconfig -d -u `echo $mfs_root_dev | sed 's/md//'`
gzip isocontents/mfsroot
boot_sector=`isoinfo -d -i $iso_image | grep Bootoff | awk '{print $3}'`
dd if=$iso_image bs=2048 count=1 skip=$boot_sector of=isocontents/boot.img
mkisofs -J -R -no-emul-boot -boot-load-size 4 -b boot.img -o new_image.iso isocontents/
mv -i new_image.iso /tftpboot/images/mfsbsd10/$iso_file

#	Clean up

umount mfsiso.mnt
mdconfig -d -u `echo $mfs_iso_dev | sed 's/md//'`
rmdir mfsiso.mnt
rmdir mfsroot.mnt