# Build diskim

`diskim` uses a (kvm) VM to do things that normally requires `sudo`,
like mounting and for making the disk image bootable. So before
`diskim` can be used you must build a kernel and a initrd for the VM.

## Define a workspace

The binary release uses the `diskim/tmp` dir as the default workspace
but when building `diskim` you should choose some other place;

```
export DISKIM_WORKSPACE=$HOME/tmp/diskim
```

The kernel, BusyBox, and other will be built in this directory. The
kernel and initrd used by `diskim` are also stored here.



### Boot-strap

Bootstrap is building the kernel and initrd used by `diskim`;

```
./diskim.sh bootstrap
```

If that doesn't work or if you want more control, do it step-by-step;

First download the Linux kernel 4.16.9 source and
[busybox](https://busybox.net/) 1.32.0 source. These should be
downloaded to the $ARCHIVE directory which defaults to
`$HOME/Downloads`. Do it manually or use;

```bash
./diskim.sh kernel_download
./diskim.sh busybox_download
./diskim.sh syslinux_download
```

Conclude the bootstrap with;

```
./diskim.sh kernel_build
./diskim.sh busybox_build
./diskim.sh syslinux_unpack
./diskim.sh initrd
```


## Release

Make a test-version;

```
ver=v0.2.0
cd /tmp
rm -rf diskim-$ver
diskim release --version=$ver - | tar x
```

In a fresh shell;

```
ver=v0.2.0
cd /tmp/diskim-$ver
./diskim.sh mkimage --image=/tmp/hd.img ./tmp/initrd.cpio
./diskim.sh xkvm --image=/tmp/hd.img root=/dev/vda
export DISKIM_WORKSPACE=/tmp/$USER/diskim
rm -rf $DISKIM_WORKSPACE
. ./test/Envsettings
# Test VirtualBox...
```

When done testing;

```
ver=v0.2.0
./diskim.sh release --version=$ver /tmp/diskim-$ver.tar
xz /tmp/diskim-$ver.tar
git tag -a $ver
git push origin $ver
```
