#! /bin/sh
##
## diskim.sh --
##
##   Create a diskimage without 'root' or 'sudo' rights.
##
##   Images can be created with the 'mkimage' command;
##
##     ./diskim.sh mkimage --image=file /path/to/my/root
##     ./diskim.sh mkimage --image=file /path/to/base [/path/to/ovl...]
##
##   For test the internal 'initrd.cpio' can be used to create an
##   image and boot a VM;
##
##     ./diskim.sh mkimage --image=/tmp/hd.img ./tmp/initrd.cpio
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
	rmtmp
	exit 1
}
help() {
	grep '^##' $0 | cut -c3-
	rmtmp
	exit 0
}
log() {
	echo "$*" >&2
}
rmtmp() {
	if test -d $tmp; then
		chmod -R u+rw $tmp
		rm -rf $tmp
	fi
}
test -n "$1" || help
echo "$1" | grep -qi "^help\|-h" && help

findf() {
	f=$HOME/Downloads/$1
	test -r $f && return 0
	test -n "$ARCHIVE" && f=$ARCHIVE/$1
	test -r $f
}
findar() {
	findf $1.tar.bz2 || findf $1.tar.gz || findf $1.tar.xz || findf $1.zip
}
# Set variables unless already defined. Vars are collected into $opts
eset() {
	local e k
	for e in $@; do
		k=$(echo $e | cut -d= -f1)
		opts="$opts|$k"
		test -n "$(eval echo \$$k)" || eval $e
	done
}

cmd_env() {
	eset \
		DISKIM_WORKSPACE=/tmp/tmp/$USER/diskim \
		KERNELDIR=$HOME/tmp/linux \
		__kver=linux-6.14.2 \
		__bbver=busybox-1.36.1 \
		syslinuxver=syslinux-6.03
		
	WS=$DISKIM_WORKSPACE
	eset \
		__kernel=$WS/bzImage \
		__initrd=$WS/initrd.cpio \
		__kdir=$KERNELDIR/$__kver \
		__kcfg=$dir/config/$__kver \
		__kobj=$WS/$__kver-obj \
		__bbcfg=$dir/config/$__bbver
	if test "$cmd" = "env"; then
		set | grep -E "^($opts)="
		findar $__kver || log "WARNING: Kernel $__kver not downloaded"
		findar $__bbver || log "WARNING: $__bbver not downloaded"
		findar $syslinuxver || log "WARNING: $syslinuxver not downloaded"
		exit 0
	fi
	mkdir -p $WS || die "Can't mkdir [$WS]"
}

cmd_release() {
	test -n "$__version" || __version=$(date +%Y.%m.%d)
	local out=$WS/diskim-$__version.tar
	test -n "$1" && out=$1
	local d=$tmp/diskim-$__version
	mkdir -p $d/tmp
	cp -R $me $dir/README.md $dir/test $d
	cp $__kernel $__initrd $d/tmp
	mkdir -p $d/tmp/$__bbver
	cp $WS/$__bbver/busybox $d/tmp/$__bbver
	rm -f $out $out.xz
	tar -C $tmp -cf "$out" diskim-$__version || die tar
	xz $out
	log "Created [$out.xz]"
}

##   Build commands;
##     build [--clean]
##     kernel_build [--kcfg=config] [--menuconfig]

cmd_build() {
	cmd_kernel_build
	cmd_busybox_build
	cmd_syslinux_unpack
	cmd_initrd
}
cmd_kernel_unpack() {
	test -f $__kdir/Kbuild && return 0   # already unpacked
	findar $__kver || die "Kernel $__kver not found"
	log "Unpacking $f to $KERNELDIR"
	tar -C $KERNELDIR -xf $f
}
cmd_kernel_build() {
	test -r $__kcfg || die "Config not readable [$__kcfg]"
	cmd_kernel_unpack
	test "$__clean" = "yes" && rm -rf $__kobj
	mkdir -p $__kobj
	cp $__kcfg $__kobj/.config

	if test "$__menuconfig" = "yes"; then
		make -C $__kdir O=$__kobj menuconfig
		cp $__kobj/.config $__kcfg
	else
		make -C $__kdir O=$__kobj oldconfig
	fi

	make -C $__kdir O=$__kobj -j$(nproc) || die "Failed to build kernel"
	mkdir -p $(dirname $__kernel)
	rm -f $__kernel
	ln $__kobj/arch/x86/boot/bzImage $__kernel
}

##     busybox_build [--bbcfg=config] [--menuconfig]
##     busybox_install --dest=dir
cmd_busybox_build() {
	test -r $__bbcfg || die "No BusyBox config [$__bbcfg]"
	local d=$WS/$__bbver
	test "$__clean" = "yes" && rm -rf $d
	if ! test -d $d; then
		findar $__bbver || die "$__bbver not downloaded"
		tar -C $WS -xf $f || die "Failed to unpack [$f]"
	fi
	cp $__bbcfg $d/.config

	if test "$__menuconfig" = "yes"; then
		make -C $d menuconfig
		cp $d/.config $__bbcfg
	else
		make -C $d oldconfig
	fi

	make -C $d -j$(nproc)
}
cmd_busybox_install() {
	test -n "$__dest" || die "No --dest"
	local bb=$WS/$__bbver/busybox
	test -x $bb || die "Not executable [$bb]"
	local ld=/lib64/ld-linux-x86-64.so.2
	test -x $ld || die "The loader not executable [$ld]"
	mkdir -p $__dest/bin
	cp $bb $__dest/bin
	ln -s busybox $__dest/bin/sh
	cmd_cprel $ld
	cmd_cplib $__dest/bin/*
}
##     syslinux_unpack
cmd_syslinux_unpack() {
	findar $syslinuxver || die "$syslinuxver not downloaded"
	test -d $WS/$syslinuxver && return 0
	log "Unpacking $syslinuxver ..."
	tar -C $WS -xf $f
}


#   emit_initrd > initrd.cpio
#     Test with; diskim.sh emit_initrd | cpio -t
cmd_emit_initrd() {
	local ld32=/lib/ld-linux.so.2
	test -x $ld32 || die "The loader32 not executable [$ld32]"
	local extlinux=$WS/$syslinuxver/bios/extlinux/extlinux
	test -x $extlinux || die "Not executable [$extlinux]"

	__dest=$tmp/rootfs
	cmd_busybox_install
	
	cp -R $dir/rootfs $tmp
	cp $extlinux $__dest/bin
	cmd_cprel $ld32
	cmd_cplib $__dest/bin/*
	cd $__dest
	find . | cpio -o -H newc
	cd - > /dev/null
}
##     initrd [--initrd=file]
cmd_initrd() {
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
##        [--bootable] [--script=file] [dir|cpio|tar...]
##       Create an image with the specified contents.
cmd_mkimage() {
	cmd_createimage
	test "$__bootable" = "yes" && xargs=bootable=yes
	cmd_ximage $@
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
	cmd_kvm "ximage $xargs" 2>&1 | grep -E 'LOG|ERROR'
}


#   createimage --image=file [--size=2G] [--format=qcow2]
cmd_createimage() {
	test -n "$__image" || die "No --image specified"
	test -n "$__size" || __size=2G
	test -n "$__uuid" || __uuid=$(uuid)
	test -n "$__format" || __format=qcow2
	test -n "$__fs" || __fs=ext3
	truncate --size=$__size "$__image" || die "Failed to create [$__image]"
	mkdir -p $tmp
	case $__fs in
		ext3)
			if ! mke2fs -t ext3 -U $__uuid -F $__image > $tmp/out 2>&1; then
				cat $tmp/out
				die "Failed to format [$__image]"
			fi
			;;
		*)
			if ! mkfs.$__fs $__image > $tmp/out 2>&1; then
				cat $tmp/out
				die "Failed to format [$__image]"
			fi
			;;
	esac
	rm -f $tmp/out
	if test "$__format" != "raw"; then
		qemu-img convert -O $__format $__image $__image.qcow2 || \
			die "Failed to convert to [$__format]"
		rm -f $__image
		mv $__image.qcow2 $__image
	fi
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
#   merge --outdir=dir [dir|cpio|tar...]
cmd_merge() {
	test "$__outdir" || die 'Not specified; --outdir'
	test -d "$__outdir" || die "Not a directory [$__outdir]"
	local n b f
	for n in $@; do
		test -r "$n" || die "Not readable [$n]"
		i=$((i+1))
		cmd_tar $n | tar -C "$__outdir" -x
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
			$n/tar -
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
	chmod -R u+rw $tmp
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
		if test "$1" = "--"; then
			shift
			break
		fi
		o=$(echo "$1" | sed -e 's,-,_,g')
		eval "$o=yes"
	fi
	long_opts="$long_opts $o"
	shift
done
unset o v
long_opts=`set | grep '^__' | cut -d= -f1`

# Execute command
trap "die Interrupted" INT TERM
cmd_env
cmd_$cmd "$@"
status=$?
rmtmp
exit $status
