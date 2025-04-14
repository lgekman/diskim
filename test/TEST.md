# diskim - test and examples

There are two cases:

1. You test a local build
2. You test a release tar-file

Make sure not to mix these! If you test a local build, the defaults
will do, but when testing a release tar-file make sure to set the
`$DISKIM_WORKSPACE` to a temporary directory for testing.

For testing a release:
```
export DISKIM_WORKSPACE=/tmp/tmp/$USER/diskim-test
rm -rf $DISKIM_WORKSPACE
cp -r ./tmp $DISKIM_WORKSPACE
```

## Self image

Create an image from the initrd used by `diskim` itself. Since
`diskim` is implemented using a disk image you may use it as an
example;

```
eval $(./diskim.sh env | grep DISKIM_WORKSPACE)
./diskim.sh mkimage --image=/tmp/hd.img $DISKIM_WORKSPACE/initrd.cpio
```

Now you can start a `kvm` using the image with:
```
./diskim.sh kvm --image=/tmp/hd.img root=/dev/vda
# Or in an xterm;
./diskim.sh xkvm --image=/tmp/hd.img root=/dev/vda
```

To terminate do `poweroff` in the VM console or do:
```
./diskim.sh kill_kvm
```


## VirtualBox

`VirtualBox` requires a bootable image and SATA support.  VirtualBox
does not support `qcow2` or `raw` disk format, but `qcow` is
fine. Setup and build the kernel;

```
# (download the kernel source archive if necessary)
export __kver=linux-6.14.2
export __kcfg=$PWD/test/virtualbox/$__kver
export __kobj=$DISKIM_WORKSPACE/test/virtualbox/obj
./diskim.sh kernel_build --kernel=$__kobj/bzImage
```

Create the image;

```
./diskim.sh mkimage --bootable --format=qcow --image=/tmp/hd-vbox.qcow test/virtualbox
```

Create a VM in `VirtualBox` and add the image in the `Storage`
configuration named `SATA` type `AHCI`.

You can also test with `kvm`;
```
qemu-system-x86_64 -M q35 -enable-kvm -smp 2 -drive file=/tmp/hd-vbox.qcow
```
