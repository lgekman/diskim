# diskim

Create disk images for VMs without root or sudo.

Example;

```bash
./diskim.sh mkimage --image=/tmp/hd.img /path/to/your/source/dir
```

If you plan to work on the same image for some time it is convenient
to set the `$__image` variable instead of specifying the parameter all
the time;

```bash
export __image=/tmp/hd.img
./diskim.sh mkimage /path/to/your/source/dir
```

An important feature of `diskim` is that you can specify multiple
sources for the image;

```bash
./diskim.sh mkimage /path/to/your/base/system \
  /path/to/ip/tools.tar /path/to/your/application ...
```

The sources can be a directory, a tar-file or a cpio file. The sources
will be copied in order to your image.

### Custom tar

Very often you want to include files that are not in your directory,
wor instance a tool from your host (e.g. `strace`). In `diskim` you
can create an executable script called `tar` in your directory and
`diskim` will use that script to create a tar-file that will be
unpacked on you image. Please see
[test/bootable/tar](test/bootable/tar) for an example.


## Build from source

`diskim` use a (kvm) VM to do things that normally requires `sudo`,
like mounting and for making the disk image bootable. So before
`diskim` can be used you must build a kernel and a initrd for the VM.

You can use;

```
export DISKIM_WORKSPACE=$HOME/tmp/diskim
./diskim.sh bootstrap
```

### Boot-strap step-by-step

If you want more control.

First download the Linux kernel 4.16.9 source and
[busybox](https://busybox.net/) 1.28.1 source. These should be
downloaded to the $ARCHIVE directory which defaults to
`$HOME/Downloads`. Do it manually or use;

```bash
./diskim.sh kernel_download
./diskim.sh busybox_download
```

The kernel and initrd will be built at $DISKIM_WORKSPACE;

```
export DISKIM_WORKSPACE=$HOME/tmp/diskim
```

Conclude the bootstrap with;

```
./diskim.sh kernel_build
./diskim.sh busybox_build
./diskim.sh initrd
```


### Test

Create an image from the initrd used by the `diskim` vm;

```
test -n "$DISKIM_WORKSPACE" || export DISKIM_WORKSPACE=$PWD/tmp
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

#### Test a bootable image

```
./diskim.sh mkimage --image=/tmp/hd.img --bootable \
  $DISKIM_WORKSPACE/initrd.cpio ./test/bootable
```

```
qemu-system-x86_64 -enable-kvm --nographic -smp 2 \
  -drive file=/tmp/hd.img,if=virtio,index=1,media=disk
```


## Create an image manually

To create an image is really quite easy. First create an empty
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
mke2fs -t ext3 -F /tmp/hd.img
```

To copy files into the image you can loopback mount it, but that
requires `sudo`;

```bash
mkdir /tmp/mnt
sudo mount -t ext3 -o loop /tmp/hd.img /tmp/mnt
sudo chmod 777 /tmp/mnt
# (copy files to /tmp/mnt)
sudo umount /tmp/mnt
```

Before unmounting you can make the image bootable with `extlinux`;

```
mkdir /tmp/mnt/boot
# (copy a kernel and extlinux.conf to /tmp/mnt/boot)
sudo extlinux -i /tmp/mnt/boot
```

Now you can convert the `raw` image to other formats if you like, for
instance `qcow2`;

```bash
qemu-img convert -O qcow2 /tmp/hd.img /tmp/hd.qcow2
```

