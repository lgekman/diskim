# diskim

This description assumes that a release is used. If you clone `diskim`
you must [build it locally](BUILD.md).

Create disk images for VMs without root or sudo.

```bash
./diskim.sh mkimage --image=/tmp/hd.img /path/to/your/source/dir
```

This will create a `qcow2` disk image with the contents from your
source dir.

An important feature of `diskim` is that you can specify multiple
sources for the image;

```bash
./diskim.sh mkimage /path/to/your/base/system \
  /path/to/ip/tools.tar /path/to/your/application ...
```

The sources can be a directory, a tar-file or a cpio file. The sources
will be copied in order to your image.

## Dependencies

`Diskim` will start a VM so `kvm` must be installed on the machine. On
Ubuntu do something like;

```
kvm-ok
# If needed;
sudo apt install qemu-kvm
sudo usermod -a -G kvm $USER
```

## Quick start

Create an image from the initrd used by `diskim` itself. Since
`diskim` is implemented using a disk image you may use it as an
example;

```
./diskim.sh mkimage --image=/tmp/hd.img ./tmp/initrd.cpio
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

## Build

Please see the [build instruction](BUILD.md).

## Test and examples

See the [test instruction](test/TEST.md). A
[VirtualBox](https://www.virtualbox.org/) example is included.


## Advanced operation and utilities

### Set default options

If you plan to work on the same image for some time it is convenient
to set the `$__image` variable instead of specifying the parameter all
the time;

```bash
export __image=/tmp/hd.img
./diskim.sh mkimage /path/to/your/source/dir
```

### Custom tar

Very often you want to include files that are not in your directory,
wor instance a tool from your host (e.g. `strace`). In `diskim` you
can create an executable script called `tar` in your directory and
`diskim` will use that script to create a tar-file that will be
unpacked on you image. Please see
[test/bootable/tar](test/bootable/tar) for an example.

### Bootable image

`Diskim` uses the
[extlinux](https://www.syslinux.org/wiki/index.php?title=EXTLINUX)
boot loader to create bootable images. Use the `--bootable`
option. Note that you must install a Linux kernel and `extlinux.conf`
on the image. Please see [test/bootable/tar](test/bootable/tar) for an
example.

```
./diskim.sh mkimage --image=/tmp/hd.img --bootable \
  $DISKIM_WORKSPACE/initrd.cpio ./test/bootable
```

Test with;

```
qemu-system-x86_64 -enable-kvm --nographic -smp 2 \
  -drive file=/tmp/hd.img,if=virtio,index=1,media=disk
```


## Create an image manually

If you don't like `diskim` or need some feature not supported you may
want to create an image manually. It is really quite easy, but you
will need `sudo`.

First create an empty file;

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
```

Before unmounting you can make the image bootable with
`extlinux`;

```
mkdir /tmp/mnt/boot
# (copy a kernel and extlinux.conf to /tmp/mnt/boot)
sudo extlinux -i /tmp/mnt/boot
```

Unmount the image;

```
sudo umount /tmp/mnt
```

Now you can convert the `raw` image to other formats if you like, for
instance `qcow2`;

```bash
qemu-img convert -O qcow2 /tmp/hd.img /tmp/hd.qcow2
```

