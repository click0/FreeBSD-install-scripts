#!/bin/sh

# https://gregoryo.wordpress.com/2015/04/15/mfsbsd-tweaks-to-help-automation/

# untested

# Mount the ISO, clone its contents, mount the root filesystem

mkdir dist
fetch -o dist http://mfsbsd.vx.sk/files/iso/10/amd64/mfsbsd-10.1-RELEASE-amd64.iso
iso_image=dist/mfsbsd-10.1-RELEASE-amd64.iso
mkdir mfsiso.mnt
mfs_iso_dev=`sudo mdconfig -a -t vnode -f $iso_image`
sudo mount_cd9660 /dev/$mfs_iso_dev mfsiso.mnt
mkdir isocontents
cp -Rp mfsiso.mnt/* isocontents/
gunzip isocontents/mfsroot.gz
mkdir mfsroot.mnt
mfs_root_dev=`sudo mdconfig -a -t vnode -f isocontents/mfsroot`
sudo mount /dev/$mfs_root_dev mfsroot.mnt

#	Make desired modifications

### autologin ###
sudo sed -i '' -e 's/:ht:np:/:al=root:ht:np:/' mfsroot.mnt/etc/gettytab
### .login automatic operations ###
sudo chmod g+w mfsroot.mnt/root/{,.login}
cat > mfsroot.mnt/root/prepare.sh <<__eof_prepare__
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
__eof_prepare__
chmod ug+x mfsroot.mnt/root/prepare.sh
sudo chown root mfsroot.mnt/root/prepare.sh
cat > mfsroot.mnt/root/.login <<__eof_login__
/root/prepare.sh \$tty && /root/deploy.sh
__eof_login__
sudo chmod g-w mfsroot.mnt/root/{,.login}
echo 'autoboot_delay="2"' >> isocontents/boot/loader.conf

#	Unmount and repackage the image to a new ISO[1]

sudo umount mfsroot.mnt
sudo mdconfig -d -u `echo $mfs_root_dev | sed 's/md//'`
gzip isocontents/mfsroot
boot_sector=`isoinfo -d -i $iso_image | grep Bootoff | awk '{print $3}'`
dd if=$iso_image bs=2048 count=1 skip=$boot_sector of=isocontents/boot.img
mkisofs -J -R -no-emul-boot -boot-load-size 4 -b boot.img -o new_image.iso isocontents/
sudo mv -i new_image.iso /tftpboot/images/mfsbsd10/mfsbsd-10.1-RELEASE-amd64.iso

#	Clean up

sudo umount mfsiso.mnt
sudo mdconfig -d -u `echo $mfs_iso_dev | sed 's/md//'`
rmdir mfsiso.mnt
rmdir mfsroot.mnt