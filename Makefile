export PATH /opt/toolchain/aarch64-linux-gnu/bin:$(PATH)
export PATH /opt/toolchain/arm-linux-gnueabi/bin:$(PATH)

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

console:
	$(RUN) bash

all:
	$(RUN) $(MAKE) build

.PHONY: all shofel2 coreboot u-boot linux imx_usb_loader librecore-utils exploit

