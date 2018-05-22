# diskim

Create disk images for VMs without root or sudo.

Example;

```bash
./diskim.sh mkimage --image=/tmp/hd.img /path/to/your/source/dir
```

## Boot-strap

`diskim` use a (kvm) VM to do things that normally requires `sudo`,
like mounting and for making the disk image bootable. So before
`diskim` can be used you must build a kernel and a initrd for the VM.
You can use;

```
./diskim.sh bootstrap
```

which will do everything necessary, or do it step-by-step as described
below for more control.

First download the Linux kernel 4.16.9 source and
[busybox](https://busybox.net/) 1.28.1 source. These should be
downloaded to the $ARCHIVE directory which defaults to
`$HOME/Downloads`. Do it manually or use;

```bash
./diskim.sh kernel_download
./diskim.sh busybox_download
```

The kernel and initrd will be built at;

```
export DISKIM_WORKSPACE=$HOME/tmp/diskim
```

here shown with it's default. Conclude the bootstrap with;

```
./diskim.sh kernel_build
./diskim.sh busybox_build
./diskim.sh initrd
```
## Test

Create an image from the initrd used by the `diskim` vm;

```
test -n "$DISKIM_WORKSPACE" || export DISKIM_WORKSPACE=$HOME/tmp/diskim
./diskim.sh mkimage --image=/tmp/hd.img $DISKIM_WORKSPACE/initrd.cpio
```

Now you can start a `kvm` using the image with;

```
./diskim.sh kvm --image=/tmp/hd.img root=/dev/vda
# Or in an xterm;
./diskim.sh xkvm --image=/tmp/hd.img root=/dev/vda
```

To terminate do `poweroff` in the VM console or do;

```
./diskim.sh kill_kvm
```

## Create an image manually

To create an image is really quite easy. Fists create an empty
file;

```bash
truncate /tmp/hd.img --size=2G
```

Note that the file is "sparse" it looks like a 2G file but it is
really empty and takes 0 (zero) byte on disk;

```
> ls -lsh /tmp/hd.img
0 -rw-rw-r-- 1 lgekman lgekman 2,0G maj 22 17:05 /tmp/hd.img
```

Now format the image;

```bash
mke2fs -t ext4 -F /tmp/hd.img
```

To copy files into the image you can loopback mount it, but that
requires `sudo`;

```bash
mkdir /tmp/mnt
sudo mount -t ext4 -o loop /tmp/hd.img /tmp/mnt
# (copy files to /tmp/mnt)
sudo umount /tmp/mnt
```

Now you can convert the `raw` image to other formats if you like, for
instance `qcow2`;

```bash
qemu-img convert -O qcow2 /tmp/hd.img /tmp/hd.qcow2
```

