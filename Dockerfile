FROM base/devel

ENV GCC_64 https://releases.linaro.org/components/toolchain/binaries/latest-7/aarch64-linux-gnu/gcc-linaro-7.2.1-2017.11-x86_64_aarch64-linux-gnu.tar.xz
ENV GCC_ARM https://releases.linaro.org/components/toolchain/binaries/latest-7/arm-linux-gnueabi/gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabi.tar.xz
ENV BRCM_URL https://chromium.googlesource.com/chromiumos/third_party/linux-firmware/+/f151f016b4fe656399f199e28cabf8d658bcb52b/brcm/brcmfmac4356-pcie.txt?format=TEXT

ENV PATH $PATH:/opt/toolchain/aarch64-linux-gnu/bin:/opt/toolchain/arm-linux-gnueabi/bin

RUN pacman -Sy --noconfirm \
  unzip \
	swig \
	python3 \
	python-pyusb \
	bc \
	cmake \
	git \
	wget

# Download / Install toolchain
RUN mkdir /opt/toolchain && cd /opt/toolchain && \
  wget -O brcmfmac4356-pcie.txt -nv "$BRCM_URL" && \
	wget -O gcc_aarch64-linux-gnu.tar.gz -nv "$GCC_64" && \
	wget -O gcc_arm-linux-gnueabi.tar.gz -nv "$GCC_ARM" && \
  mv brcmfmac4356-pcie.txt /lib/firmware/brcm/ && \
	tar -xf gcc_aarch64-linux-gnu.tar.gz && \
	tar -xf gcc_arm-linux-gnueabi.tar.gz && \
	ln -s gcc*aarch64-linux-gnu aarch64-linux-gnu && \
	ln -s gcc*arm-linux-gnueabi arm-linux-gnueabi && \
	rm *.tar.gz

VOLUME /source
WORKDIR /source

CMD bash
