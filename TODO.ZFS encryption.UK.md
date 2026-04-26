# TODO: Підтримка шифрування ZFS

## Огляд

Додати підтримку шифрування дисків до інсталяційного скрипта `gozfs.sh`.
Два підходи: GELI (рідне для FreeBSD) та рідне шифрування ZFS (OpenZFS 2.0+).

## Методи шифрування

### Варіант A: GELI (geom_eli)

Повне шифрування диска на рівні GEOM, нижче за ZFS.

**Переваги:**
- Зріле, добре протестоване рішення у FreeBSD з версії 7.0
- `loader.efi` / `gptzfsboot` нативно підтримують запит пароля GELI під час завантаження
- Шифрує все, включно з метаданими ZFS
- Працює як з BIOS, так і з UEFI завантаженням

**Недоліки:**
- Накладні витрати на продуктивність (додатковий шар GEOM)
- Неможливо використовувати ZFS send/recv для зашифрованих даних (розшифровуються на рівні GEOM)
- Управління ключами прив'язане до FreeBSD (не переносиме на Linux/інші OpenZFS)

**Розмітка розділів:**
```
[boot] [ESP*] [swap (GELI)] [ZFS на GELI-провайдері]
```

**Ключові кроки реалізації:**
1. Нова опція: `-E geli`
2. Після створення ZFS-розділу під'єднати GELI до створення zpool:
   - `geli init -bg -s 4096 /dev/gpt/system-<label>`
   - `geli attach /dev/gpt/system-<label>`
3. Створити zpool на `/dev/gpt/system-<label>.eli` замість сирого розділу
4. Додати до `loader.conf`:
   - `geom_eli_load="YES"`
   - `vfs.root.mountfrom="zfs:poolname"`
5. Додати до `/etc/rc.conf`:
   - `geli_devices="gpt/system-<label>"`
   - Або обробляти через `geli_autodetach`
6. Шифрування swap: `geli onetime -s 4096 /dev/gpt/swap-<label>`
   - Додати суфікс `.eli` у fstab

### Варіант B: Рідне шифрування ZFS (OpenZFS 2.0+)

Шифрування на рівні окремих datasets всередині ZFS. Потребує FreeBSD 13.0+.

**Переваги:**
- Гранулярність на рівні dataset (шифрувати лише потрібне)
- `zfs send -w` надсилає зашифровані дані (без розшифровування)
- Переноситься між платформами OpenZFS (Linux, FreeBSD)
- Менші накладні витрати, ніж у GELI

**Недоліки:**
- Метадані ZFS (імена datasets, розміри) **НЕ** шифруються
- `loader.efi` не вміє розблокувати зашифровані datasets — потрібна незашифрована boot pool/dataset
- Потрібна окрема незашифрована область `/boot`
- Лише FreeBSD 13.0+

**Розмітка розділів:**
```
[boot] [ESP*] [swap] [ZFS]
  └── poolname (незашифрований)
       ├── poolname/bootpool (незашифрований, mountpoint=/boot)
       └── poolname/encrypted (зашифрований, encryptionroot)
            ├── poolname/encrypted/root (mountpoint=/)
            ├── poolname/encrypted/usr
            ├── poolname/encrypted/var
            └── ...
```

**Ключові кроки реалізації:**
1. Нова опція: `-E native`
2. Створити zpool як зазвичай (незашифрований кореневий dataset)
3. Створити незашифрований boot dataset:
   - `zfs create -o mountpoint=/boot poolname/boot`
4. Створити зашифрований батьківський dataset:
   - `zfs create -o encryption=aes-256-gcm -o keylocation=prompt -o keyformat=passphrase poolname/encrypted`
5. Створити дочірні datasets під зашифрованим батьківським (вони успадкують шифрування)
6. Модифікувати ZFS skeleton, щоб використовувати префікс `poolname/encrypted/`
7. Додати до `/etc/rc.conf`:
   - Обробити завантаження ключа під час старту (запит або файл-ключ)

## Нова CLI-опція

```
-E <encryption_mode>    Режим шифрування: none (за замовчуванням), geli, native
```

## Спільні вимоги (для обох методів)

- [ ] Запит пароля під час встановлення (інтерактивно) або прийняття через опцію `-P`
- [ ] Шифрування swap (GELI onetime для обох методів)
- [ ] Оновити `loader.conf` потрібними модулями
- [ ] Оновити `check_size()` з урахуванням накладних витрат GELI (~0.5% + метадані)
- [ ] Тестова матриця: BIOS/UEFI/hybrid x GELI/native x single/mirror/raidz
- [ ] Документація у README-файлах (EN, RU, UK)

## ESP та шифрування

Для UEFI-завантаження з шифруванням:
- ESP залишається **незашифрованим** (FAT32 з `loader.efi`) — цього вимагає специфікація UEFI
- GELI: `loader.efi` запитує пароль перед монтуванням кореневого ZFS
- Native: `loader.efi` завантажує ядро з незашифрованого boot dataset, потім `rc.d`-скрипти розблоковують зашифровані datasets

## Посилання

- [FreeBSD Handbook: Disk Encryption](https://docs.freebsd.org/en/books/handbook/disks/#disks-encrypting)
- [geli(8)](https://man.freebsd.org/cgi/man.cgi?geli(8))
- [OpenZFS Native Encryption](https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Encryption.html)
- [FreeBSD Wiki: Root on ZFS with GELI](https://wiki.freebsd.org/RootOnZFS/GPTZFSBoot)
- [FreeBSD 13 Release Notes: OpenZFS 2.0](https://www.freebsd.org/releases/13.0R/relnotes/)
