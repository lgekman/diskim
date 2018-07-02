diskim - test and examples
==========================

First setup the `diskim` environment for test;

```
export DISKIM_WORKSPACE=$HOME/tmp/diskom
. ./test/Envsettings
```

You can set `$DISKIM_WORKSPACE` to another directory, the example
shows the default.


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
export __kver=linux-4.17.3
export __kcfg=$DISKIM_DIR/test/virtualbox/linux-4.17.3
export __kobj=$DISKIM_WORKSPACE/test/virtualbox/obj
export __bootable=yes
export __image=$DISKIM_WORKSPACE/test/virtualbox/hd.qcow
export __format=qcow
diskim kernel_download
diskim kernel_unpack
diskim kernel_build --kernel=$__kobj/bzImage
```

Create the image;

```
diskim mkimage  $DISKIM_DIR/test/virtualbox
```

Create a VM and add the image in the `Storage` configuration as `SATA`
type `AHCI`.
