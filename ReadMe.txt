

Если работает DHCP

	1) есть rescue FreeBSD с ZFS ==> ставим через go11_4k.sh
	2) есть rescue FreeBSD без ZFS ==> пишем MfsBSD.img сразу на /dev/ada0
	3) если есть возможность грузить ISO ==> грузим MfsBSD и с него ставим через go11_4k.sh
	4) если есть установленная Linux ==> то через GRUB, ISO MfsBSD, kFreeBSD
	5) если есть rescue Linux ==> тогда в vKVM (статически слинкованный qemu) грузим ISO MfsBSD, пробрасываем /dev/sda, через ssh или VNC клиент устанавливаем с ISO систему, потом правим сеть и пробуем перегрузить хост машину.


Если НЕ работает DHCP

	1) если есть установленная Linux ==> то через GRUB, GRUB-ISO, kFreeBSD со сменой сетевых настроек
	2) есть rescue FreeBSD с ZFS ==> перепаковываем MfsBSD.img и потом пишем на /dev/ada0
	3) если есть возможность грузить ISO ==> модифицируем MfsBSD, грузимся с нашего образа и с него ставим через go11_4k.sh

Примечания:
	MfsBSD НЕ поддерживает IPv6
	не все версии MfsBSD грузятся нормально

Эталон
	mfsbsd-se-11.0-RELEASE-amd64.iso
	
Untested
	https://sysadmin.pm/takeover-sh/
	Convert_UFS_to_ZFS.sh

Исходные ресурсы:
	https://github.com/clickbg/scripts/blob/c5c90b8475ba32337de9fdb8808113d32f922454/FreeBSD/freebsd_81_zfs_install.sh

Deprecated:
	go11.sh
