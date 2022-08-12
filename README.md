# A set of scripts for installing FreeBSD
Here is a set of scripts intended for a guaranteed installation of the FreeBSD OS.

### Set composition
***
- `go11.sh` - script to install FreeBSD on disks with block size 512.
- `go11_4k.sh` - script to install FreeBSD on disks with block size 4k or 8k.
- `install_mfsbsd_img_to_sda.sh` - script to write [MfsBSD](https://mfsbsd.vx.sk) .img _to a running_ Linux system on the first HDD (with non-guaranteed results)
- `install_mfsbsd_iso.sh` - script to write [MfsBSD](https://mfsbsd.vx.sk) ISO _on a running_ Linux system
- `mfsbsd_repack.sh` - script for repacking the MfsBSD image with the addition of network settings.
- `archive/` - directory with old source scripts.
- `untested/` - directory with untested scripts.

### Description

For installation, a standard MfsBSD image is used, where there is a `tmux` application and `root|mfsroot` accesses.  
We do not need the FreeBSD archives in the image, we will download them separately from our own or public http server.  
Access to the new system, if no new password was specified in the arguments, after setting the scripts `go11.sh`/`go11_4k.sh` - `rootmfsroot123`.  
MfsBSD does **NOT** support IPv6.

### Usage strategies
***

##### If DHCP works

1. there is rescue FreeBSD with ZFS ==> install via `go11_4k.sh`
2. there is rescue FreeBSD without ZFS ==> write MfsBSD.img directly to /dev/ada0
3. it is possible to load ISO ==> load MfsBSD and install inside it via `go11_4k.sh`
4. there is Linux installed ==> then via GRUB, GRUB-IMAGEBOOT, ISO MfsBSD, kFreeBSD
5. there is rescue Linux ==> then in vKVM (statically linked qemu) we load ISO MfsBSD, we forward /dev/sda, through ssh or VNC the client install with ISO system, then we correct a network and we try to reboot a host machine.

##### If DHCP is **NOT** working

6. there is Linux installed ==> then via GRUB, GRUB-IMAGEBOOT, ISO MfsBSD, kFreeBSD
7. there is rescue FreeBSD with ZFS ==> repack MfsBSD.img and then write to /dev/ada0
8. it is possible to load ISO ==> modify MfsBSD, boot from our image and install the system from it via `go11_4k.sh`

### Script syntax

- `go11.sh`/`go11_4k.sh`
  
        sh go11_4k.sh -p vtbd0 -p vtbd1 -s4G -n zroot

    Full syntax:
    ```
    # sh go11_4k.sh -p <geom_provider> -s <swap_partition_size> -S <zfs_partition_size> -n <zpoolname> -f <ftphost>
    [ -m <zpool-raidmode> -d <distdir> -M <size_memory_disk> -o <offset_end_disk> -a <ashift_disk>]
    [ -g <gateway> [-i <iface>] -I <IP_address/mask> ]
    ```

- `install_mfsbsd_iso.sh`

        sh install_mfsbsd_iso.sh standard
    or
 
        sh install_mfsbsd_iso.sh standard 13.0 my_hostname
    Full syntax:
    ```
    # sh install_mfsbsd_iso.sh (mini|standard|se) [ 13.0 ] [ <hostname> ] [ fxp0 ] [ 250 ]
    ```

- other scripts without arguments


###### Untested
    https://sysadmin.pm/takeover-sh/
    Convert_UFS_to_ZFS.sh

###### Source resources:
[freebsd_81_zfs_install.sh](https://github.com/clickbg/scripts/blob/c5c90b8475ba32337de9fdb8808113d32f922454/FreeBSD/freebsd_81_zfs_install.sh)

###### Deprecated:
- `go11.sh`
- `mfsbsd_repack.sh`

## 🤝 Contributing

Contributions, issues and feature requests are welcome!<br />Feel free to check [issues page](https://github.com/click0/domain-check-2/issues).

## Show your support

Give a ⭐ if this project helped you!

<a href="https://www.buymeacoffee.com/click0" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-orange.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
