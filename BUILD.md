# Build diskim

`diskim` uses a (kvm) VM to do things that normally requires `sudo`,
like mounting and for making the disk image bootable. So before
`diskim` can be used you must build a kernel and a initrd for the VM.

## Prepare

The kernel source is unpacked in the `$KERNELDIR` directory (defaults
to "$HOME/tmp/linux"). The kernel is built in `$DISKIM_WORKSPACE` so
the kernel source is not altered and can be used for other builds.
If you *want* the kernel source in `$DISKIM_WORKSPACE`, do:

```
eval $(./diskim.sh env | grep DISKIM_WORKSPACE)
export KERNELDIR=$DISKIM_WORKSPACE
```

Download the kernel, BusyBox and [syslinux](
https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux) archives to
`$HOME/Downloads` or `$ARCHIVE`. Check versions with:

```
./diskim.sh env
```



## Build

Bootstrap is building the kernel and initrd used by `diskim`;

```
./diskim.sh build --clean        # build all from scratch
```

If that doesn't work or if you want more control, do it step-by-step;

```
./diskim.sh kernel_build
./diskim.sh busybox_build
./diskim.sh syslinux_unpack
./diskim.sh initrd
```

## Release


```
./diskim.sh release
# Use the created archive below
testdir=/tmp
tar -C $testdir -xf (file from above)
```

Test it in a fresh shell as described [here](test/TEST.md).


When done testing:
```
ver=(some real release version)
./diskim.sh release --version=$ver
git tag $ver
git push origin $ver
```
