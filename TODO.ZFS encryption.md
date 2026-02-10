# TODO: ZFS Encryption Support

## Overview

Add disk encryption support to `gozfs.sh` and `gozfs_512b.sh` installation scripts.
Two approaches: GELI (FreeBSD native) and ZFS native encryption (OpenZFS 2.0+).

## Encryption Methods

### Option A: GELI (geom_eli)

Full-disk encryption at the GEOM layer, below ZFS.

**Pros:**
- Mature, well-tested on FreeBSD since 7.0
- `loader.efi` / `gptzfsboot` natively support GELI password prompt at boot
- Encrypts everything including ZFS metadata
- Works with both BIOS and UEFI boot

**Cons:**
- Performance overhead (extra GEOM layer)
- Cannot use ZFS send/recv on encrypted data (decrypted at GEOM level)
- Key management tied to FreeBSD (not portable to Linux/other OpenZFS)

**Partition layout:**
```
[boot] [ESP*] [swap (GELI)] [ZFS on GELI provider]
```

**Key implementation steps:**
1. New option: `-E geli`
2. After creating ZFS partition, attach GELI before creating zpool:
   - `geli init -bg -s 4096 /dev/gpt/system-<label>`
   - `geli attach /dev/gpt/system-<label>`
3. Create zpool on `/dev/gpt/system-<label>.eli` instead of raw partition
4. Add to `loader.conf`:
   - `geom_eli_load="YES"`
   - `vfs.root.mountfrom="zfs:poolname"`
5. Add to `/etc/rc.conf`:
   - `geli_devices="gpt/system-<label>"`
   - Or handle via `geli_autodetach`
6. Swap encryption: `geli onetime -s 4096 /dev/gpt/swap-<label>`
   - Add `.eli` suffix in fstab

### Option B: ZFS Native Encryption (OpenZFS 2.0+)

Per-dataset encryption within ZFS. Requires FreeBSD 13.0+.

**Pros:**
- Per-dataset granularity (encrypt only what needed)
- `zfs send -w` sends encrypted data (no decryption needed)
- Portable across OpenZFS platforms (Linux, FreeBSD)
- Less performance overhead than GELI

**Cons:**
- ZFS metadata (dataset names, sizes) is NOT encrypted
- `loader.efi` cannot unlock encrypted datasets — need unencrypted boot pool/dataset
- Requires separate unencrypted `/boot` area
- FreeBSD 13.0+ only

**Partition layout:**
```
[boot] [ESP*] [swap] [ZFS]
  └── poolname (unencrypted)
       ├── poolname/bootpool (unencrypted, mountpoint=/boot)
       └── poolname/encrypted (encrypted, encryptionroot)
            ├── poolname/encrypted/root (mountpoint=/)
            ├── poolname/encrypted/usr
            ├── poolname/encrypted/var
            └── ...
```

**Key implementation steps:**
1. New option: `-E native`
2. Create zpool as usual (unencrypted root dataset)
3. Create unencrypted boot dataset:
   - `zfs create -o mountpoint=/boot poolname/boot`
4. Create encrypted parent dataset:
   - `zfs create -o encryption=aes-256-gcm -o keylocation=prompt -o keyformat=passphrase poolname/encrypted`
5. Create child datasets under encrypted parent (they inherit encryption)
6. Modify ZFS skeleton to use `poolname/encrypted/` prefix
7. Add to `/etc/rc.conf`:
   - Handle key loading at boot (prompt or keyfile)

## New CLI Option

```
-E <encryption_mode>    Encryption mode: none (default), geli, native
```

## Shared Requirements (both methods)

- [ ] Password prompt during install (interactive) or accept via `-P` option
- [ ] Swap encryption (GELI onetime for both methods)
- [ ] Update `loader.conf` with required modules
- [ ] Update `check_size()` to account for GELI overhead (~0.5% + metadata)
- [ ] Test matrix: BIOS/UEFI/hybrid x GELI/native x single/mirror/raidz
- [ ] Documentation in README files (EN, RU, UK)

## ESP and Encryption

For UEFI boot with encryption:
- ESP remains **unencrypted** (FAT32 with `loader.efi`) — this is required by UEFI spec
- GELI: `loader.efi` prompts for password before mounting root ZFS
- Native: `loader.efi` loads kernel from unencrypted boot dataset, then `rc.d` scripts unlock encrypted datasets

## References

- [FreeBSD Handbook: Disk Encryption](https://docs.freebsd.org/en/books/handbook/disks/#disks-encrypting)
- [geli(8)](https://man.freebsd.org/cgi/man.cgi?geli(8))
- [OpenZFS Native Encryption](https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Encryption.html)
- [FreeBSD Wiki: Root on ZFS with GELI](https://wiki.freebsd.org/RootOnZFS/GPTZFSBoot)
- [FreeBSD 13 Release Notes: OpenZFS 2.0](https://www.freebsd.org/releases/13.0R/relnotes/)
