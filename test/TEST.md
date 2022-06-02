# diskim - test and examples

First setup the `diskim` environment for test;

```
export DISKIM_WORKSPACE=$HOME/tmp/diskim
. ./test/Envsettings
```

You can set `$DISKIM_WORKSPACE` to another directory, the example
shows the default.

If you don't use a `diskim` release you must [build locally](../BUILD.md);
```
./diskim.sh bootstrap
```

## Self image

Create an image from the initrd used by `diskim` itself. Since
`diskim` is implemented using a disk image you may use it as an
example;

```
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


## VirtualBox

`VirtualBox` requires a bootable image and SATA support.  VirtualBox
does not support `qcow2` or `raw` disk format, but `qcow` is
fine. Setup and build the kernel;

```
export __kver=linux-5.18.1
export __kcfg=$DISKIM_DIR/test/virtualbox/$__kver
export __kobj=$DISKIM_WORKSPACE/test/virtualbox/obj
diskim kernel_download
diskim kernel_unpack
diskim kernel_build --kernel=$__kobj/bzImage
```

Create the image;

```
diskim mkimage --bootable --format=qcow \
  --image=/tmp/hd-vbox.qcow $DISKIM_DIR/test/virtualbox
```

Create a VM in `VirtualBox` and add the image in the `Storage`
configuration named `SATA` type `AHCI`.

You can also test with `kvm`;
```
qemu-system-x86_64 -M q35 -enable-kvm -smp 2 -drive file=/tmp/hd-vbox.qcow
```
