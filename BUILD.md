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
[busybox](https://busybox.net/) 1.28.1 source. These should be
downloaded to the $ARCHIVE directory which defaults to
`$HOME/Downloads`. Do it manually or use;

```bash
./diskim.sh kernel_download
./diskim.sh busybox_download
```

Conclude the bootstrap with;

```
./diskim.sh kernel_build
./diskim.sh busybox_build
./diskim.sh initrd
```

