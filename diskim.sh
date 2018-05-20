#! /bin/sh
##
## diskim.sh --
##   Create a diskimage without 'root' or 'sudo' rights.
##
##   Kvm/qemu is used to format images and install boot-loader. This
##   requires a "boot-strap" image (or rather initrd.cpio) and kernel
##   that in turn is used to create other images.
##
##   The directory where the boot-strap items are is configured in;
##
##     export DISKIM_WORKSPACE=$HOME/tmp/diskim
##
##   Create boot-strap kernel and initrd.cpio;
##
##     ./diskim.sh kernel_unpack
##     ./diskim.sh kernel_build
##     ./diskim.sh busybox_download
##     ./diskim.sh busybox_build
##     ./diskim.sh initrd
##
##   New images can now be created with the 'mkimage' command;
##
##     ./diskim.sh mkimage /path/to/my/root
##
##   For test the boot-strap 'initrd.cpio' can be used to create an
##   image and boot a VM;
##
##     ./diskim.sh mkimage --image=/tmp/hd.img $DISKIM_WORKSPACE/initrd.cpio
##     ./diskim.sh kvm --image=/tmp/hd.img root=/dev/vda
##     ./diskim.sh xkvm --image=/tmp/hd.img root=/dev/vda  # (uses "xterm")
##
##   Check things on the system and then use "poweroff" to exit. Or;
##
##     ./diskim.sh kill_kvm
##
##
##   Commands
##   --------
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
me=$dir/$prg
tmp=${TMPDIR:-/tmp}/${prg}_$$

die() {
	echo "ERROR: $*" >&2
	rm -rf $tmp
	exit 1
}
help() {
	grep '^##' $0 | cut -c3-
	rm -rf $tmp
	exit 0
}
test -n "$1" || help
echo "$1" | grep -qi "^help\|-h" && help

cmd_env() {
	test -n "$DISKIM_WORKSPACE" || DISKIM_WORKSPACE=$HOME/tmp/diskim
	test -n "$ARCHIVE" || ARCHIVE=$HOME/Downloads
	mkdir -p $DISKIM_WORKSPACE $ARCHIVE
	test -n "$__kver" || __kver=linux-4.16.9
	test -n "$__kdir" || __kdir=$DISKIM_WORKSPACE/$__kver
	test -n "$__kcfg" || __kcfg=$dir/config/$__kver
	test -n "$__kobj" || __kobj=$DISKIM_WORKSPACE/obj
	test -n "$__bbver" || __bbver=busybox-1.28.1
	test -n "$__bbcfg" || __bbcfg=$dir/config/$__bbver
	test -n "$__kernel" || __kernel=$DISKIM_WORKSPACE/bzImage
	test -n "$__initrd" || __initrd=$DISKIM_WORKSPACE/initrd.cpio
}

##   Bootstrap commands;
##     kernel_unpack
##     kernel_build [--kcfg=config] [--menuconfig]
cmd_kernel_unpack() {
	cmd_env
	if test -e $__kdir; then
		echo "Already unpacked [$__kdir]"
		test -d $__kdir || die "Not a directory [$__kdir]"
		return 0
	fi
	local ar=$ARCHIVE/$__kver.tar.xz
	test -r $ar || die "Not readable [$ar]"
	tar -C $(dirname $__kdir) -I pxz -xf $ar
}
cmd_kernel_build() {
	cmd_env
	mkdir -p $__kobj
	if test -r $__kcfg; then
		cp $__kcfg $__kobj/.config
	else
		make -C $__kdir O=$__kobj allnoconfig
		__menuconfig=yes
	fi

	if test "$__menuconfig" = "yes"; then
		make -C $__kdir O=$__kobj menuconfig
		cp $__kobj/.config $__kcfg
	else
		make -C $__kdir O=$__kobj oldconfig
	fi

	make -C $__kdir O=$__kobj -j4 || die "Failed to build kernel"
	mkdir -p $(dirname $__kernel)
	rm -f $__kernel
	ln $__kobj/arch/x86/boot/bzImage $__kernel
}

##     busybox_download
##     busybox_build [--bbcfg=config] [--menuconfig]
cmd_busybox_download() {
	local url ar
	cmd_env
	ar=$ARCHIVE/$__bbver.tar.bz2
	if test -r $ar; then
		echo "Already downloaded [$ar]"
	else
		url=http://busybox.net/downloads/$__bbver.tar.bz2
		curl -L $url > $ar || die "Could not download [$url]"
	fi
}
cmd_busybox_build() {
	cmd_env
	local d=$DISKIM_WORKSPACE/$__bbver
	if ! test -d $d; then
		cmd_busybox_download
		tar -C $DISKIM_WORKSPACE -xf $ARCHIVE/$__bbver.tar.bz2 ||\
			die "Failed to unpack [$ARCHIVE/$__bbver.tar.bz2]"
	fi
	if test -r $__bbcfg; then
		cp $__bbcfg $d/.config
	else
		make -C $d allnoconfig
		__menuconfig=yes
	fi

	if test "$__menuconfig" = "yes"; then
		make -C $d menuconfig
		cp $d/.config $__bbcfg
	else
		make -C $d oldconfig
	fi

	make -C $d -j4
}

#   emit_initrd > initrd.cpio
#     Test with; diskim.sh emit_initrd | cpio -t
cmd_emit_initrd() {
	cmd_env
	local bb=$DISKIM_WORKSPACE/$__bbver/busybox
	test -x $bb || die "Not executable [$bb]"
	local ld=/lib64/ld-linux-x86-64.so.2
	test -x $ld || die "The loader not executable [$ld]"

	mkdir -p $tmp
	cp -R $dir/rootfs $tmp
	__dest=$tmp/rootfs
	mkdir -p $__dest/bin
	cp $bb $__dest/bin
	ln -s busybox $__dest/bin/sh
	cmd_cprel $ld
	local f
	for f in mke2fs strace; do
		f=$(which $f)
		test -x "$f" || die "Not executable [$f]"
		cp $f $__dest/bin
	done
	cmd_cplib $__dest/bin/*
	cd $__dest
	find . | cpio -o -H newc
	cd - > /dev/null
}
##     initrd [--initrd=file]
cmd_initrd() {
	cmd_env
	mkdir -p $(dirname $__initrd)
	cmd_emit_initrd > $__initrd
}

##
##   Utility and test commands;

cmd_cprel() {
	test -n "$__dest" || die 'No --dest'
	test -d "$__dest" || die "Not a directory [$__dest]"
	local n d
	for n in $@; do
		test -r $n || die "Not readable [$n]"
		d=$__dest/$(dirname $n)
		mkdir -p $d
		cp -L $n $d
	done
}

##     cplib --dest=dir [program...]
##       Copy libs that the commands needs (uses 'ldd').
cmd_cplib() {
	test -n "$__dest" || die 'No --dest'
	test -d "$__dest" || die "Not a directory [$__dest]"
	local x f d
	mkdir -p $tmp
	f=$tmp/ldd
	for x in $@; do
		ldd $x | grep '=> /' | sed -re 's,.*=> (/[^ ]+) .*,\1,' >> $f
	done
	cmd_cprel $(sort $f | uniq)
}
##     kvm --image=file [--iso=file] [kernel-params...]
cmd_kvm() {
	cmd_env
	test -n "$__image" || die 'Not specified; --image'
	test -r "$__image" || die "Not readable [$__image]"
	test -f "$__image" || die "Not a file [$__image]"
	cmd_kill_kvm > /dev/null 2>&1
	local args
	if test -n "$__iso"; then
		test -r "$__iso" || die "Not readable [$__iso]"
		test -f "$__iso" || die "Not a file [$__iso]"
		args="-drive file=$__iso,if=virtio,index=2,media=cdrom"
	fi
	export DISKIM=running
	qemu-system-x86_64 -enable-kvm --nographic -smp 2 \
		-drive file=$__image,if=virtio,index=1,media=disk \
		$args \
		-kernel $__kernel -initrd $__initrd -append "init=/init $@"
}
##     xkvm --image=file [kernel-params...]
cmd_xkvm() {
	xterm -fd wheat -bg '#224' -e $me kvm --image=$__image $@ &
}
##     kill_kvm
cmd_kill_kvm() {
	kill $(grep -lsF DISKIM=running /proc/*/environ | tr -sc '0-9' ' ')
}

##
##   Image commands;

##     mkimage --image=file [--format=qcow2] [--size=2G] \
##        [--uuid=uuid] [--script=file] [dir|cpio|tar...]
##       Create an image with the specified contents.
cmd_mkimage() {
	cmd_createimage
	mkdir -p $tmp
	__iso=$tmp/cd.iso
	cmd_createiso $@
	test -n "$__uuid" || __uuid=$(uuid)
	cmd_kvm mkimage=$__uuid  2>&1 | grep -E 'LOG|ERROR'
}

##     ximage --image=file [--script=file] [dir|cpio|tar...]
##       Extend an image with new data.
cmd_ximage() {
	test -n "$__image" || die 'Not specified; --image'
	test -r "$__image" || die "Not readable [$__image]"
	test -f "$__image" || die "Not a file [$__image]"
	mkdir -p $tmp
	__iso=$tmp/cd.iso
	cmd_createiso $@
	cmd_kvm ximage  2>&1 | grep -E 'LOG|ERROR'
}


#   createimage --image=file [--format=qcow2] [--size=2G]
cmd_createimage() {
	test -n "$__image" || die "No --image specified"
	test -n "$__size" || __size=2G
	test -n "$__format" || __format=qcow2
	touch "$__image" 2> /dev/null || die "Not writable [$__image]"
	rm -f "$__image"
	qemu-img create -f $__format -o size=$__size $__image > /dev/null || \
		die "Failed to create [$__image]"
}

#   createiso --iso=file [--script=file] [dir|cpio|tar...]
cmd_createiso() {
	test "$__iso" || die 'Not specified; --iso'
	touch "$__iso" 2> /dev/null || die "Not writable [$__iso]"
	rm -f "$__iso"
	__outdir=$tmp/isoroot
	mkdir -p $__outdir
	if test -n "$__script"; then
		test -r "$__script" || die "Not readable [$__script]"
		cp "$__script" $__outdir/diskim
	fi
	cmd_collect $@
	genisoimage -R -o $__iso $__outdir 2> /dev/null || die "Failed; genisoimage"
	ls $__outdir
	rm -r $__outdir
}
#   collect --outdir=dir [dir|cpio|tar...]
cmd_collect() {
	test "$__outdir" || die 'Not specified; --outdir'
	test -d "$__outdir" || die "Not a directory [$__outdir]"
	local n b i=0 f
	for n in $@; do
		test -r "$n" || die "Not readable [$n]"
		i=$((i+1))
		b=$(basename $n | grep -oE '^[^.]+')
		f=$(printf '%02d%s.tar' $i $b)
		cmd_tar $n > "$__outdir/$f"
	done
}
#   tar <dir|tar|cpio>
#     Will convert the passed item to an uncompressed tar on stdout
cmd_tar() {
	test -n "$1" || return 0
	test -r "$1" || die "Not readable [$1]"
	local n=$(readlink -f "$1")

	if test -d $n; then
		if test -x $n/tar; then
			$n/tar
		else
			cd $n
			tar --sparse -c *
			cd - > /dev/null
		fi
		return 0
	fi

	mkdir -p $tmp/tar
	cd $tmp/tar

	if echo "$n" | grep -qE '.*\.cpio$'; then
		cpio -id < $n > /dev/null 2>&1
	else
		tar xf $n || die "Tar failed [$n]"
	fi

	tar --sparse -c *
	cd - > /dev/null
	rm -rf $tmp/tar
}

##
# Get the command
cmd=$1
shift
grep -q "^cmd_$cmd()" $0 || die "Invalid command [$cmd]"

while echo "$1" | grep -q '^--'; do
	if echo $1 | grep -q =; then
		o=$(echo "$1" | cut -d= -f1 | sed -e 's,-,_,g')
		v=$(echo "$1" | cut -d= -f2-)
		eval "$o=\"$v\""
	else
		o=$(echo "$1" | sed -e 's,-,_,g')
		eval "$o=yes"
	fi
	shift
done
unset o v
long_opts=`set | grep '^__' | cut -d= -f1`

# Execute command
trap "die Interrupted" INT TERM
#mkdir -p $tmp
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
