#! /bin/sh
##
## diskim.sh --
##   Create a diskimage without 'root' or 'sudo' rights.
##
##   Uses kvm/qemu to format images and install boot-loader.
##

prg=$(basename $0)
dir=$(dirname $0); dir=$(readlink -f $dir)
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
	test -n "$ARCHIVE" || ARCHIVE=$HOME/archive
	mkdir -p $DISKIM_WORKSPACE $ARCHIVE
	test -n "$__kver" || __kver=linux-4.15.9
	test -n "$__kdir" || __kdir=$ARCHIVE/$__kver
	test -n "$__kcfg" || __kcfg=$dir/config/$__kver
	test -n "$__kobj" || __kobj=$DISKIM_WORKSPACE/$__kver
	test -n "$__bbver" || __bbver=busybox-1.28.1
	test -n "$__bbcfg" || __bbcfg=$dir/config/$__bbver
}

## Bootstrap commands;
##   kernel_unpack
##   kernel_build [--kcfg=config] [--menuconfig]
cmd_kernel_unpack() {
	cmd_env
	if test -e $__kdir; then
		echo "Already unpacked [$__kdir]"
		test -d $__kdir || die "Not a directory [$__kdir]"
		return 0
	fi
	local ar=$ARCHIVE/$__kver.tar.xz
	test -r $ar || die "Not readable [$ar]"
	tar -C $(dirname $__kdir) -xf $ar
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
	cp $__kobj/arch/x86_64/boot/bzImage $dir
}

##   busybox_download
##   busybox_build [--bbcfg=config] [--menuconfig]
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

#   initrd > initrd.cpio
#     Test with; diskim image | cpio -t
cmd_initrd() {
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
	cmd_cplib $__dest/bin/*
	cd $__dest
	find . | cpio -o -H newc
	cd - > /dev/null
}
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
##
## Utility commands;

##   cplib --dest=dir [program...]
##     Copy libs that the commands needs (uses 'ldd').
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

##
## Image commands;
cmd_kvm() {
	test -n "$__kernel" || __kernel=$dir/bzImage
	test -n "$__initrd" || __initrd=$dir/initrd.cpio
	qemu-system-x86_64 -enable-kvm --nographic \
		-kernel $__kernel -initrd $__initrd -append init=/bin/busybox
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
