# Build diskim

`diskim` uses a (kvm) VM to do things that normally requires `sudo`,
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

