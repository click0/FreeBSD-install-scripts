#!/usr/bin/env sh
which sudo >/dev/null && exec sudo sh || exec su -l root -c 'exec sh'
newpool="$(hostname -s)"
extradisk="$(mdconfig -a -t swap -s 1T)"
bootdisk=$( (test -e /dev/ada0 && echo ada0) || (test -e /dev/da0 && echo da0) || (test -e /dev/xbd0 && echo xbd0) || (test -e /dev/nvd0 && echo nvd0) || echo oops )
umount /dev/${extradisk}[ps]*
gpart destroy -F ${extradisk}
gpart create -s gpt -n 152 ${extradisk}
gpart add -t freebsd-boot -b 40 -s 1090 -l ${newpool}.boot1 ${extradisk}
tmpsize=$( (gpart show -lp ${bootdisk} | egrep '^=>' | (read junk offset size junk && echo $((size-1048576)) ); gpart show -lp ${extradisk} | egrep '^=>' | (read junk offset size junk && echo $((size/2-1048576)) ) ) | sort -n | head -n 1 )
gpart add -t freebsd-zfs -b 256M -s ${tmpsize} -l ${newpool}.zfs1 ${extradisk}
gpart add -t freebsd-zfs -s ${tmpsize} -l ${newpool}.zfs0 ${extradisk}
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 ${extradisk}
kldload zfs
sysctl vfs.zfs.min_auto_ashift=12
zpool create -fo altroot=/xmnt -o autoexpand=on -O mountpoint=/ -O canmount=off -O atime=off -O compression=lz4 -O recordsize=1M -O redundant_metadata=most -O com.sun:auto-snapshot=true ${newpool} mirror /dev/gpt/${newpool}.zfs?
zfs create -o recordsize=128K ${newpool}/.
zpool set bootfs=${newpool}/. ${newpool}
zpool offline ${newpool} /dev/gpt/${newpool}.zfs0
gpart delete -i3 ${extradisk}
gpart resize -i2 ${extradisk}
zpool online -e ${newpool} /dev/gpt/${newpool}.zfs1
tar --one-file-system -C / -cpf - . | tar -C /xmnt -xpf -
rm -d /xmnt/boot/zfs/zpool.cache /xmnt/xmnt
egrep -v '^/dev/[^[:space:]]+[[:space:]]+/[[:space:]]' /etc/fstab > /xmnt/etc/fstab
echo 'zfs_load="YES"' >> /xmnt/boot/loader.conf
echo 'zfs_enable="YES"' >> /xmnt/etc/rc.conf
zpool export ${newpool}
rmdir /xmnt
kenv vfs.root.mountfrom=zfs:${newpool}/.
reboot -r