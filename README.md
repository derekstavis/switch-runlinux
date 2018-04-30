# Switch Run Linux

This repo contains a script which can be used to run Linux on Nintendo
Switch using failoverfl0w ShofEL2 exploit. The instructions to load Linux
is scattered between the blog post and ShofEL2 repo so I decided to create
this repo to ease build and run process.

To run Linux on your Switch follow this simple instructions:

1. Clone the repo:

```
git clone https://github.com/derekstavis/switch-runlinux
```

2. Download the Pixel C factory image [from here][pixel-c-image].
3. Place the downloaded file inside `switch-runlinux` repository.
4. Build the toolchain (you need Docker installed):

```
make toolchain
```

5. Build the needed tools:

```
make build
```

6. Have the Switch into RCM mode and run the exploit:

```
make run
```

[pixel-c-image]: https://developers.google.com/android/images#ryu
