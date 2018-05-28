export PATH /opt/toolchain/aarch64-linux-gnu/bin:$(PATH)
export PATH /opt/toolchain/arm-linux-gnueabi/bin:$(PATH)

ARCHLINUX_TAR := ArchLinuxARM-aarch64-latest.tar.gz
ARCHLINUX_URL := http://os.archlinuxarm.org/os/$(ARCHLINUX_TAR)

CLONE := git clone --depth=1

MAKE := make -j1
XMAKE := CROSS_COMPILE=aarch64-linux-gnu- $(MAKE)
X64MAKE := ARCH=arm64 $(XMAKE)

RUN := docker run --privileged -ti --rm -v $(shell pwd):/source switch-linux-toolchain:latest

librecore-utils:
	test -d librecore-utils || $(CLONE) https://github.com/librecore-org/librecore-utils.git librecore-utils
	ls -lah librecore-utils
	mkdir -p librecore-utils/build
	cd librecore-utils/build && cmake ..
	$(MAKE) librecore-utils/build

shofel2:
	test -d shofel2 || $(CLONE) https://github.com/fail0verflow/shofel2.git
	make -C shofel2/exploit

u-boot:
	test -d u-boot || $(CLONE) https://github.com/fail0verflow/switch-u-boot.git u-boot
	$(XMAKE) -C u-boot nintendo-switch_defconfig
	$(XMAKE) -C u-boot

coreboot: u-boot
	test -d coreboot || $(CLONE) --recursive https://github.com/fail0verflow/switch-coreboot.git coreboot
	$(XMAKE) tegra_mtc
	$(XMAKE) -C coreboot nintendo_switch_defconfig
	$(XMAKE) -C coreboot iasl
	$(XMAKE) -C coreboot

imx_usb_loader:
	test -d imx_usb_loader || $(CLONE) https://github.com/boundarydevices/imx_usb_loader.git
	$(MAKE) -C imx_usb_loader

linux:
	test -d linux || $(CLONE) https://github.com/fail0verflow/switch-linux.git linux
	$(X64MAKE) -C linux nintendo-switch_defconfig
	$(X64MAKE) -C linux

tegra_mtc: librecore-utils
	unzip -f ryu-mxb48j-factory-*.zip
	librecore-utils/build/cbfstool/cbfstool ryu-mxb48j/bootloader-dragon-google_smaug.7132.260.0.img extract -n fallback/tegra_mtc -f coreboot/tegra_mtc.bin

build: shofel2 coreboot u-boot linux imx_usb_loader tegra_mtc

toolchain:
	docker build . -ti switch-linux-toolchain

shofel2-run:
	$(RUN) bash -c 'cd shofel2/exploit && \
		python shofel2.py cbfs.bin ../../coreboot/build/coreboot.rom'
	@sleep 3

usb-loader:
	$(RUN) bash -c 'cd shofel2/usb_loader && \
		../../u-boot/tools/mkimage -A arm64 -T script -C none -n "boot.scr" -d switch.scr switch.scr.img && \
		../../imx_usb_loader/imx_usb -c .'

run: shofel2-run usb-loader

MOUNTPOINT=mnt
PACMAN_CACHE=cache/.local-cache

$(MOUNTPOINT):
	mkdir -p $(MOUNTPOINT)

$(PACMAN_CACHE):
	mkdir -p $(PACMAN_CACHE)
	sudo mount -o bind cache $(MOUNTPOINT)/var/cache/pacman/pkg

$(MOUNTPOINT)/dev: $(MOUNTPOINT)
	sudo mount /dev/sdb2 $(MOUNTPOINT)

$(MOUNTPOINT)/dev/tty: $(MOUNTPOINT)/dev
	$(foreach name,dev dev/pts proc sys,sudo mount -o bind /$(name) $(MOUNTPOINT)/$(name);)

chroot: $(MOUNTPOINT)/dev/tty
	sudo chroot mnt

umount:
	mount | grep $(MOUNTPOINT) | cut -d\  -f3 | sort -u | tac | xargs sudo umount

QEMU=$(shell which qemu-aarch64-static)

$(MOUNTPOINT)/$(QEMU):
	sudo cp $(QEMU) $(MOUNTPOINT)/$(QEMU)

$(MOUNTPOINT)/usr/share: $(MOUNTPOINT) ./ArchLinuxARM-aarch64-latest.tar.gz
	test -e $(MOUNTPOINT)/usr/share || sudo bsdtar -xpUf $(ARCHLINUX_TAR) -C $(MOUNTPOINT)

./ArchLinuxARM-aarch64-latest.tar.gz:
	wget $(ARCHLINUX_URL)

base-system: $(MOUNTPOINT) ./ArchLinuxARM-aarch64-latest.tar.gz $(MOUNTPOINT)/usr/share

$(MOUNTPOINT)/etc/udev/rules.d/switch-ts-calibration.rules:
	sudo cp shofel2/configs/switch-ts-calibration.rules $(MOUNTPOINT)/etc/udev/rules.d/

$(MOUNTPOINT)/usr/bin/xinitrc-header:
	sudo cp shofel2/configs/xinitrc-header.sh $(MOUNTPOINT)/usr/bin/xinitrc-header
	sudo sed -i '1i#!/bin/bash' $(MOUNTPOINT)/usr/bin/xinitrc-header
	sudo chmod +x $(MOUNTPOINT)/usr/bin/xinitrc-header

xorg-fixup: $(MOUNTPOINT)/etc/udev/rules.d/switch-ts-calibration.rules $(MOUNTPOINT)/usr/bin/xinitrc-header

$(MOUNTPOINT)/var/lib/pacman/local/gnome-shell-.*: $(MOUNTPOINT)/$(QEMU) $(MOUNPOINT)/dev/tty xorg-fixup $(PACMAN_CACHE)
	# sudo chroot $(MOUNTPOINT) /usr/bin/pacman -Sy gnome networkmanager xorg-xinput xorg-xrandr
	grep xinit-header $(MOUNTPOINT)/usr/lib/systemd/system/gdm.service || \
		sudo sed -i \
			's/\(\[Service\]\)/\1\nExecStartPre=\/usr\/bin\/xinitrc-header/g' \
			$(MOUNTPOINT)/usr/lib/systemd/system/gdm.service

$(MOUNTPOINT)/etc/systemd/system/display-manager.service: $(MOUNTPOINT)/$(QEMU) $(MOUNTPOINT)/dev/tty
	sudo chroot $(MOUNTPOINT) /usr/bin/systemctl enable gdm NetworkManager

gnome: $(MOUNTPOINT)/var/lib/pacman/local/gnome-shell-.* $(MOUNTPOINT)/etc/systemd/system/display-manager.service

reboot-script:
	sudo cp -r auto-reboot.service mnt/usr/lib/systemd/system
	sudo chroot $(MOUNTPOINT) /usr/bin/systemctl enable auto-reboot


userland: base-system gnome

console:
	$(RUN) bash

all:
	$(RUN) $(MAKE) build

.PHONY: all shofel2 coreboot u-boot linux imx_usb_loader librecore-utils exploit

