#
# Android build environment for Columbia SSL
# (C) 2011-2013 Jeremy C. Andrus <jeremya@cs.columbia.edu>
#
# Once setup properly, this script provides a set of built-in shell
# functions and aliases to build/boot/flash a kernel, and copy
# relevant files from an android compilation to a separate directory.
# It also wraps up a few commonly used android shell commands.
#
# ----------
# Variables:
# (prompts if not found)
# ----------
# ANDROID_ROOT : root of the Android source tree
#
# ANDROID_IMGS : path to directory which will be used to archive images
#              : also the location of userdata-qemu.img and sdcard.img
#              : emulator images
#
# ANDROID_KERNEL_DIR : directory containing the Android kernel source
#
# [deprecated - to be removed soon...]
# ANDROID_DFLT_IMGDIR : default directory to look for system.img, userdata.img,
#                     : etc. - must be a subdirectory of ANDROID_IMGS!
#
# [deprecated - to be removed soon...]
# ANDROID_DFLT_PRODUCT : default product output directory to use
#                      : (e.g. generic, or passion)
#
# ----------
# Optional variables
# ----------
# ADD_ANDROID_HOST_BIN_TO_PATH   : add the host binary output to your path
#                                : defaults to 1 (pretty useful)
#
# ADD_PREBUILT_TOOLCHAIN_TO_PATH : add the prebuilt ARM toolchain to your path
#                                : defaults to 1

# ----------
# Usage
# ----------
# Source this file directly and pass the lunch combo as an argument
# e.g. "user@host$ source ./android-env.sh full_grouper-eng
#
# Optional arguments:
# 	-nosrc      : Don't invoke "lunch" and don't expect the Android sources
#                     to be present. This can be handy if you just want a shell
#                     environment without having an entire Android tree.
#
# 	-remote     : Experimental (highly untested) remote environment
#                     (allows limited use of this environment from a remote machine)

# ----------
# Commands added by this scripts are documented as follows
# ----------

# Command : emu
# Function: Run the Android emulator
# Usage   : emu [-b|-tree|-k|-imgs /images/path] {additional emulator parameters}
# Note    : this uses the stock kernel by default, please pass a -kernel option
#           to boot a custom kernel (or the -k option for: -kernel arch/arm/boot/zImage)
#         -b     : Run in the background
#         -tree  : Run emulator using Android tree images (not a custom images directory)
#         -k     : Pass '-kernel $ANDROID_KERNEL_DIR/arch/arm/boot/zImage' to emulator
#         -imgs [/path/to/cpimgs/output] : boot emulator using provided images (not default)
#                                          (accepts paths relative to $ANDROID_IMGS, and
#                                           respects your lunch combo!)
#
#         All other parameters are passed directory to the Android 'emulator'
#         binary program
#
# Command : rfa
# Function: Run 'repo forall -c' in a more user-friendly way
# Usage   : rfa [-h] command arg1 arg2...
#
# Command : cpimgs
# Function: Copy the relevant output images from an android compilation
# Usage   : cpimgs [-h] /path/to/image_destination {android_product_name}
# Note    : accepts paths relative to $ANDROID_IMGS
#
# Command : kbuild
# Function: Kernel cross-compilation wrapper
#           Compilation output is set to Android platform object directory
#           (currently: $OUT/obj/KERNEL)"
# Usage   : kbuild [options] [make parameters]"
#                  -h|--help           shows this text"
#                  --pincc[=prefix]    sets CROSS_COMPILE=prefix"
#                                      (defaults to $cc_cross)"
#                  [make parameters]  parameters passed directly to make"
#
# Command : kconfig
# Function: configure the Linux kernel for ARM processors
# Usage   : kconfig
#
# Command : kmodules
# Function: build and install the Android Linux kernel modules
# Usage   : kmodules
#
# Command : kboot
# Function: boot a custom kernel on a device (via fastboot)
# Usage   : kboot
# Note    : have your phone/device plugged in and in fastboot mode
#
# Command : aflash
# Function: flash a set of images onto a device
# Usage   : aflash /path/to/images {/path/to/kernel}
# Usage   : aflash [-b|-k|-imgs]
#               -b                      : flash only the boot partition
#               -nb                     : SKIP flashing the boot partition
#               -k [/path/to/kernel]    : path to the kernel image (or directory)
#               -stock                  : Use boot.img (the stock) _not_ a custom
#                                         built boot image
#               -imgs [/path/to/imgdir] : path to a directory containing compiled
#                                         Android images (defaults to $ANDROID_PRODUCT_OUT)
#
# Note    : If you pass the optional kernel path, it can be to the zImage, or
#           to the top-level dir where 'arch/arm/boot/zImage' can be found.
#
# Command : apush
# Function: push some files to an android device via adb
# Usage   : apush [-h] [system_dir] [file-glob] {dest}
#             -h          : show this help screen"
#             [sysdir]    : directory under \$TOP/out/target/product/\$TARGET_PRODUCT/"
#                           to search for [path-glob]"
#                           e.g. bin"
#             [path-glob] : path(s) to file(s) to push"
#                           e.g. \"*cell*\""
#             {dst_dir}   : optional parameter to specify the directory on"
#                           the device into which [path-glob] will be placed"
# Example:
#     To push all files in \$TOP/out/target/product/\$TARGET_PRODUCT/system/bin
#     whose file names contain 'ril' (e.g. libril.so) onto the sdcard of the device
#     you would do:
#         apush system/bin \"*ril*\" /sdcard"
#
# Note    : This utility will push a (set of) file(s) to an android device.
#           It assumes that the files you are looking for can be found in:
#               $TOP/out/target/product/${TARGET_DEVICE}/(system_dir)
#           and can be found using an ls command in the above directory using
#           the provided file (glob)
#
#           File globs should be enclosed in quotes to prevent your shell
#           from expanding them.

######################################################################
########## Configuration
######################################################################

export ANDROID_JAVA_HOME=$JAVA_HOME

export COLUMBIA_REXEC_FILE=
export COLUMBIA_REXEC_OUTPUT=

# silly mac osx work-around...
E=$(which -a echo | grep -v "aliased to" | head -1)
if [ `echo -e "foo"` = "foo" ]; then
	E="echo"
fi

# setup remote execution
# (i.e. this script is being sourced by someone connected over SSH)
export COLUMBIA_REXEC_EN=0
export COLUMBIA_NOSRC=0
if [ "$1" = "-remote" ]; then
	shift
	$E "Initializing remote development environment"
	COLUMBIA_REXEC_EN=1
elif [ "$1" = "-nosrc" ]; then
	shift
	$E "Initializing function-only environment (no lunch)"
	# add local directory to the path
	local script_dir=`cd $(dirname $0) && pwd`
	__scriptdir=$(echo $PATH | sed "s#${script_dir}[a-zA-Z0-9/\-_ ]\{1,\}:*##g; s#.*:*\(${script_dir}\).*#\1#")
	if [ "${__scriptdir}" != "${script_dir}" ]; then
		echo "adding ${script_dir} to your path..."
		eval export PATH="$script_dir:$PATH"
	fi
	COLUMBIA_NOSRC=1
else
	$E "Initializing local environment"
fi

# Even-More-Better ZSH support
function __pushd() {
	if [ "$(basename $SHELL)" = "zsh" -a "$zshPushedLvl" = "" ];then
		zshWAS_IGNORING_PUSHDUP=$(setopt |grep -i pushdignoredups)
		setopt noPUSHD_IGNORE_DUPS
	fi
	zshPushedLvl="1${zshPushedLvl}"
	pushd $@
}

function __popd() {
	popd
	zshPushedLvl=${zshPushedLvl:1}
	if [ "$(basename $SHELL)" = "zsh" -a "$zshPushedLvl" = "" ];then
		if [ ! "$zshWAS_IGNORING_PUSHDUP" = "" ]; then
			setopt PUSHD_IGNORE_DUPS
		fi
	fi
}

PUSHD='pushd'
POPD='popd'
IDXOFST=0
if [ "$(basename $SHELL)" = "zsh" ];then
	PUSHD='__pushd'
	POPD='__popd'
	# In ZSH, array indices start at 1... thanks
	# use the following variable to fix this like:
	#     ((idxvar=$idxvar + $IDXOFST))
	IDXOFST=1
fi

# Check the environment!
if [ $COLUMBIA_NOSRC -eq 1 ]; then
	export ANDROID_ROOT=`pwd`
	export ANDROID_IMGS=`pwd`
	export ANDROID_KERNEL_DIR=`pwd`/kernel
else
if [ -z "$ANDROID_ROOT" ]; then
	__aroot=`pwd`
	$E -n "Android root directory [${__aroot}]: "
	read ANDROID_ROOT
	if [ -z "$ANDROID_ROOT" ]; then
		ANDROID_ROOT=${__aroot}
	fi
	export ANDROID_ROOT
fi

if [ -z "$ANDROID_IMGS" ]; then
	__aimgs=`pwd`/img
	$E -n "A directory to place output images [${__aimgs}]: "
	read ANDROID_IMGS
	if [ -z "$ANDROID_IMGS" ]; then
		ANDROID_IMGS=${__aimgs}
	fi
	export ANDROID_IMGS
fi

if [ -z "$ANDROID_KERNEL_DIR" ]; then
	__akernel=${ANDROID_ROOT}/kernel
	$E -n "Android kernel directory [${__akernel}]: "
	read ANDROID_KERNEL_DIR
	if [ -z "$ANDROID_KERNEL_DIR" ]; then
		ANDROID_KERNEL_DIR=${__akernel}
	fi
	export ANDROID_KERNEL_DIR
fi
fi # !$COLUMBIA_NOSRC

#
# this doesn't _exactly_ mirror the way android determines this value,
# but for most systems it should be OK
export ANDROID_HOSTARCH=`uname -sm | tr [A-Z] [a-z] | sed 's/cygwin/windows/' | sed 's/ /-/' | sed 's/[3-6ix]*86.*/x86/'`

# add the Android host binary path to your path (pretty useful)
if [ -z "$ADD_ANDROID_HOST_BIN_TO_PATH" ]; then
	ADD_ANDROID_HOST_BIN_TO_PATH=1
fi
export ANDROID_HOST_BIN="$ANDROID_ROOT/out/host/$ANDROID_HOSTARCH/bin"

# don't add this by default - Android does that itself now...
if [ -z "$ADD_PREBUILT_TOOLCHAIN_TO_PATH" ]; then
	ADD_PREBUILT_TOOLCHAIN_TO_PATH=1
fi

#
# source the official Android environment setup
# (and extract any proprietary binary blobs)
#
eval $PUSHD "$ANDROID_ROOT" > /dev/null
eval export TOP="$ANDROID_ROOT"

# The Android Environment
if [ $COLUMBIA_NOSRC -eq 1 ]; then
	$E "bypassing lunch combo selection"
else
	eval source "./build/envsetup.sh" >/dev/null
	lunch $@
fi

# work around crazy 'ls' option setups :-)
export __LS=$(which -a ls | grep -v "aliased to" | head -1)

if [ ! $COLUMBIA_NOSRC -eq 1 ]; then
# Blob extraction: First find a reasonable manufacturer
#                  based on lunch combo, then see if we
#                  have a corresponding entry in ./vendor
___mfr=$(get_build_var TARGET_PRODUCT)
# __mfr is actually the _product_ right now
__mfr=${___mfr##*_}
# find the product under "/device" and extract the manufacturer name (which is the directory above)
_mfr=$(find ./device -maxdepth 2 -type d -name ${__mfr} | sed -e "s,/${__mfr}.*,,; s,.*/,,g")
$E "Checking for vendor files from: $_mfr"
if [ -z "$($__LS -1 ./vendor/${_mfr} 2>/dev/null)" -a ! "${_mfr}" = "generic" ]; then
	if [ -x ./extract-proprietary-blobs.sh ]; then
		$E "\tExtracting proprietary binary blobs..."
		sleep 1
		./extract-proprietary-blobs.sh
	fi
fi
fi
$POPD >/dev/null

# find the most recent toolchain provided...
if [ ! $COLUMBIA_NOSRC -eq 1 ]; then
__highest=0
if [ -z "$ARM_EABI_TOOLCHAIN" -a "$ADD_PREBUILT_TOOLCHAIN_TO_PATH" = "1" -o "$FORCE_TOOLCHAIN_SEARCH" = "1" ]; then
	__tarch=$(get_build_var TARGET_ARCH)
	for tc in `find $ANDROID_ROOT/prebuilt/$ANDROID_HOSTARCH/toolchain -maxdepth 1 -name ${__tarch}-*`; do
		v=$(echo $tc | sed "s#.*/${__tarch}-.*-\([0-9][0-9]*\)\.\([0-9][0-9]*\)\\(.\([0-9x][0-9x]*\)\)*#\1\2\4#")
		vv=$(echo $v | sed "s#\([0-9x]\)#\1.#g")
		if [ ${#v} -lt 3 ]; then
			v="${v}0"
		fi
		__gcc=$($__LS -1 $tc/bin/${__tarch}*gcc-${vv%%.}* 2>/dev/null)
		if [ -x $__gcc ]; then
			v=${v/x/0}
			if [[ $v -gt $__highest ]]; then
				__highest=$v
				export ARM_EABI_TOOLCHAIN=$tc/bin
				export ANDROID_CROSS_COMPILE=${__gcc%gcc*}
			fi
		fi
	done
elif [ ! -z "$ARM_EABI_TOOLCHAIN" ]; then
	__tarch=$(get_build_var TARGET_ARCH)
	if [ -z "$ANDROID_CROSS_COMPILE" ]; then
		__gcc=$($__LS -1 ${ARM_EABI_TOOLCHAIN}/${__tarch}*gcc 2>/dev/null)
		if [ -x $__gcc ]; then
			export ANDROID_CROSS_COMPILE=${__gcc%gcc*}
		fi
	fi
fi

if [ -z "$ARM_EABI_TOOLCHAIN" ]; then
	$E "XXX: hmmm, I didn't find a toolchain in '$ANDROID_ROOT', and you didn't specify one."
	$E "XXX: I need a toolchain!"
else
	$E "Using toolchain in: $ARM_EABI_TOOLCHAIN"
fi

if [ -z "$ANDROID_DFLT_IMGDIR" ]; then
	ANDROID_DFLT_IMGDIR=$(get_build_var TARGET_PRODUCT)
	export ANDROID_DFLT_IMGDIR=${ANDROID_DFLT_IMGDIR##*_}
	#$E "'ANDROID_DFLT_IMGDIR' is unset, defaulting to $ANDROID_DFLT_IMGDIR"
fi

if [ -z "$ANDROID_DFLT_PRODUCT" ]; then
	ANDROID_DFLT_PRODUCT=$(get_build_var TARGET_PRODUCT)
	export ANDROID_DFLT_PRODUCT=${ANDROID_DFLT_PRODUCT##*_}
	#$E "'ANDROID_DFLT_PRODUCT' is unset, defaulting to $ANDROID_DFLT_PRODUCT"
fi

# in OSX, elf.h doesn't exist by default...
if [ ! -r /usr/include/elf.h ]; then
	echo ""
	echo "Didn't find elf.h on your system: copying as root (password needed)..."
	echo ""
	sudo cp "$ANDROID_ROOT/vendor/columbia/build/elf.h" /usr/include/elf.h
fi

# Set VI compilation options for the kernel
$E "let android_odir='${ANDROID_ROOT}/$(get_build_var TARGET_OUT_INTERMEDIATES)'" > $ANDROID_KERNEL_DIR/.vim_kernel_env
$E "let android_modpath='${ANDROID_ROOT}/$(get_build_var TARGET_OUT_INTERMEDIATES)/KERNEL_MODULES'" >> $ANDROID_KERNEL_DIR/.vim_kernel_env
$E "let android_arch='$(get_build_var TARGET_ARCH)'" >> $ANDROID_KERNEL_DIR/.vim_kernel_env
if [ ! -z "$ANDROID_CROSS_COMPILE" ]; then
	$E "let android_cc_cross='${ANDROID_CROSS_COMPILE}'" >> $ANDROID_KERNEL_DIR/.vim_kernel_env
else
	$E "let android_cc_cross='arm-eabi-'" >> $ANDROID_KERNEL_DIR/.vim_kernel_env
fi
fi # !$COLUMBIA_NOSRC



######################################################################
########## End configuration: begin function definition
######################################################################

__chk_err() {
	if [ $? -ne 0 ]; then
		$E "\033[0;31mERROR! ($1)\033[0m"
		return -1
	fi
	return 0
}

__msg() {
	if [ "$1" = "done" ]; then
		$E -e "\t\t\033[0;32m[done]\033[0m"
	else
		$E -n -e "\033[0;33m${1}...\033[0m"
	fi
}

__rfa_usage() {
	$E "usage: rfa [cmd] {arg1 {arg2 {arg3 ...}}}"
	$E ""
}

__check_for_repo() {
	export REPO__=$(which -a repo | grep -v "aliased to" | head -1)
	if [ ! -z "$REPO__" ]; then
		return
	fi
	export REPO__="$HOME/bin/repo"
	if [ ! -x "$REPO__" ]; then
		export REPO__=
		$E "The repo command must be in your path!"
		$E "You can grab it from Google:"
		$E "$ curl http://android.git.kernel.org/repo > ~/bin/repo"
		$E "$ chmod a+x ~/bin/repo"
		return
	fi
}

__mkbootimage() {
	local MKB=$(which -a mkbootimg | grep -v "aliased to" | head -1)
	local KPATH=$1
	local RAMDISK_IMG=$2
	local BOOT_IMG=$3
	local BASE_OFST=
	local PROD_CMDLINE=

	local _TPROD=$(get_build_var TARGET_PRODUCT)
	local TPROD=${_TPROD##*_}
	if [ -z "$TPROD" ]; then
		$E "You haven't chosen a lunch combo yet."
		return
	fi

	if [ ! -e "$MKB" ]; then
		$E "ERROR: could not find mkbootimg in your path!"
		return -1
	fi
	if [ ! -e "$KPATH" -o ! -e "$RAMDISK_IMG" ]; then
		$E "ERROR: could not find kernel or ramdisk - check paths!"
		$E "       kernel : '$KPATH'"
		$E "       ramdisk: '$RAMDISK_IMG'"
		return -1
	fi
	$E -e "\033[0;32mPreparing new boot image in '$BOOT_IMG'...\033[0m"
	case "$TPROD" in
		passion) BASE_OFST="--base 0x20000000" ;;
		crespo) BASE_OFST="--base 0x30000000 --pagesize 4096" ;;
		# Nexus 7 needs more vmalloc address space!
		grouper) PROD_CMDLINE="vmalloc=512M" ;;
		*) ;;
	esac
	if [ ! -z "$BASE_OFST" ]; then
		$E -e "\033[0;31m...$TPROD requires '$BASE_OFST'...\033[0m"
	fi

	local CMDLINE="'no_console_suspend=1 console=ttyFIQ0 user_debug=31 $PROD_CMDLINE'"
	$E -e "\033[0;32m\tCommand Line: $CMDLINE\033[0m"
	eval $MKB --cmdline $CMDLINE --kernel "$KPATH" --ramdisk "$RAMDISK_IMG" $BASE_OFST -o "$BOOT_IMG"
}

__check_for_device() {
	D=
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__perform_remote_cmd "$_ADB devices | grep -v \"ist of devices\" | grep -v \"\\*\" | head -1"
		D=$(cat $COLUMBIA_REXEC_OUTPUT)
	else
		D=$($_ADB devices | grep -v "ist of devices" | grep -v "\*" | head -1)
	fi
	if [ -z "$D" ]; then
		$E "No device attached!"
		return -1
	fi
	return 0
}

__device_create_dir() {
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__perform_remote_cmd "$_ADB remount >/dev/null; $_ADB shell mount -o remount,rw /; $_ADB shell mkdir $1 >/dev/null"
	else
		$_ADB remount >/dev/null
		$_ADB shell mount -o remount,rw /
		$_ADB shell mkdir -p $1 >/dev/null
	fi
}

__device_symlink() {
	local tgt=$1
	local file=$2
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__perform_remote_cmd "$_ADB shell \"ln -s $tgt $file 2>/dev/null\""
	else
		$_ADB shell "ln -s $tgt $file 2>/dev/null"
	fi
}

__device_bind_mnt() {
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__perform_remote_cmd "$_ADB shell mount -o bind $1 $2"
	else
		$_ADB shell mount -o bind $1 $2
	fi
}

function __pushdir() {
	local srcdir=$1
	local dstdir=$2
	if [ -z "$srcdir" -o -z "$dstdir" ]; then
		$E "invalid parameters"
		return
	fi
	$E ""
	$E -e "Pushing everything in:"
	$E -e "  \033[0;33m$srcdir\033[0m"
	$E -e "to"
	$E -e "  \033[0;32m$dstdir\033[0m"
	$E    "..."
	$E ""
	$E "NOTE: requires modified adb (to sync whole directories)"

	$_ADB sync "$srcdir" "$dstdir"
	$POPD > /dev/null
}

function kbuild_help() {
	local cc_cross=$1

	$E ""
	$E "Kernel cross-compilation wrapper"
	$E "Compilation output is set to Android platform object directory"
	$E "(currently: $OUT/obj/KERNEL)"
	$E ""
	$E "usage: kbuild [options] [make parameters]"
	$E "\t-h|--help           shows this text"
	$E "\t--pincc[=prefix]    sets CROSS_COMPILE=prefix"
	$E "\t                    (defaults to $cc_cross)"
	$E "\t"
	$E "\t[make parameters]  parameters passed directly to make"
	$E ""
}

function kbuild() {
	local odir=${ANDROID_ROOT}/$(get_build_var TARGET_OUT_INTERMEDIATES)
	local modpath=${ANDROID_ROOT}/$(get_build_var TARGET_OUT_INTERMEDIATES)/KERNEL_MODULES
	local arch=$(get_build_var TARGET_ARCH)
	local cc_cross=arm-linux-androideabi-
	local verbose=

	local pincc=0
	if [ "$1" = "--pincc" ]; then
		shift
		pincc=1
	elif [ "${1:0:8}" = "--pincc=" ]; then
		cc_cross=${1:9}
		shift
		pincc=1
	fi

	if [ $pincc -eq 0 -a ! -z "$ANDROID_CROSS_COMPILE" ]; then
		cc_cross=$ANDROID_CROSS_COMPILE
	fi

	if [ "$1" = "-h" -o "$1" = "--help" ]; then
		kbuild_help "$cc_cross"
		return
	fi

	$E ""
	$E "CROSS_COMPILE=$cc_cross"
	$E ""

	if [ ! -z "$(get_build_var SHOW_COMMANDS)" ]; then
		verbose="V=1"
	fi

	odir="$odir/KERNEL"
	if [ ! -d "$odir" ]; then
		mkdir -p "$odir"
	fi
	if [ ! -d "$modpath" ]; then
		mkdir -p "$modpath"
	fi

	eval make -C "$ANDROID_KERNEL_DIR" ARCH=$arch CROSS_COMPILE=$cc_cross O=$odir INSTALL_MOD_PATH=$modpath $verbose $@
	RET=$?
	if [[ "$1" == "cscope" ]]; then
		CP=$(which -a cp | grep -v "aliased to" |head -1)
		$CP -f $odir/cscope* "$ANDROID_KERNEL_DIR"/.
	fi
	return $RET
}

function kconfig() {
	kbuild menuconfig
}

function kmodules() {
	local CP=$(which -a cp | grep -v "aliased to" | head -1)
	local moddir=${ANDROID_ROOT}/$(get_build_var TARGET_OUT_INTERMEDIATES)/KERNEL_MODULES
	local tgtdir=${ANDROID_ROOT}/$(get_build_var TARGET_OUT)/lib/modules
	mkdir -p $moddir 2>&1 >/dev/null
	mkdir -p $tgtdir 2>&1 >/dev/null
	kbuild modules
	kbuild modules_install
	$CP -vf `find ${moddir} -name *.ko` ${tgtdir}
}

function kheaders() {
	local pdir=${ANDROID_ROOT}/$(get_build_var PRODUCT_OUT)
	kbuild "INSTALL_HDR_PATH=${pdir}/kernel_inc" headers_install
}

function __rexec_cleanup() {
	rm -f "$REXEC_FILE"
}

function __prep_remote_server() {
	COLUMBIA_REXEC_FILE=/tmp/rexec_prep.$$.tmp
	COLUMBIA_REXEC_OUTPUT=/tmp/rexec_out.$$.tmp
	RDC="$TOP/vendor/columbia/build/remote-dev-client.pl"
	REXEC=$(cat <<-SETVAR
		RECEIVE_FILE#$_ADB#
		$(uuencode -m $_ADB -)___END_FILE___
	SETVAR)
	echo "$REXEC" > $COLUMBIA_REXEC_FILE
	$RDC "$COLUMBIA_REXEC_FILE" $COLUMBIA_REXEC_OUTPUT
	REXEC=$(cat <<-SETVAR
		RECEIVE_FILE#$_FB#
		$(uuencode -m $_FB -)___END_FILE___
	SETVAR)
	echo "$REXEC" > $COLUMBIA_REXEC_FILE
	$RDC "$COLUMBIA_REXEC_FILE" $COLUMBIA_REXEC_OUTPUT
	REXEC=$(cat <<-SETVAR
		RECEIVE_FILE#$_ARM_GDB#
		$(uuencode -m $_ARM_GDB -)___END_FILE___
	SETVAR)
	echo "$REXEC" > $COLUMBIA_REXEC_FILE
	$RDC "$COLUMBIA_REXEC_FILE" $COLUMBIA_REXEC_OUTPUT
	REXEC=$(cat <<-SETVAR
		RECEIVE_FILE#$_IOS_GDBINIT#
		$(uuencode -m $_IOS_GDBINIT -)___END_FILE___
	SETVAR)
	echo "$REXEC" > $COLUMBIA_REXEC_FILE
	$RDC "$COLUMBIA_REXEC_FILE" $COLUMBIA_REXEC_OUTPUT
	REXEC=$(cat <<-SETVAR
		START_COMMAND
		#!/bin/bash
		chmod 755 $_FB
		chmod 755 $_ADB
		chmod 755 $_ARM_GDB
		chmod 744 $_IOS_GDBINIT
		rm fastboot adb arm-gdb
		ln -s $_FB ./fastboot
		ln -s $_ADB ./adb
		ln -s $_ARM_GDB ./arm-gdb
		___END_COMMAND___
	SETVAR)
	echo "$REXEC" > $COLUMBIA_REXEC_FILE
	$RDC "$COLUMBIA_REXEC_FILE" $COLUMBIA_REXEC_OUTPUT
	__rexec_cleanup
}

function __perform_remote_cmd() {
	COLUMBIA_REXEC_FILE=/tmp/rexec_prep.$$.tmp
	COLUMBIA_REXEC_OUTPUT=/tmp/rexec_out.$$.tmp
	echo "START_COMMAND\n$@\n___END_COMMAND___\n" > $COLUMBIA_REXEC_FILE
	RDC="$TOP/vendor/columbia/build/remote-dev-client.pl"
	$RDC $COLUMBIA_REXEC_FILE $COLUMBIA_REXEC_OUTPUT
	__rexec_cleanup
}

function __perform_iremote_cmd() {
	COLUMBIA_REXEC_FILE=/tmp/rexec_prep.$$.tmp
	COLUMBIA_REXEC_OUTPUT=/tmp/rexec_out.$$.tmp
	echo "START_COMMAND\n$@\n___END_COMMAND___\n" > $COLUMBIA_REXEC_FILE
	RDC="$TOP/vendor/columbia/build/remote-dev-client.pl"
	$RDC $COLUMBIA_REXEC_FILE $COLUMBIA_REXEC_OUTPUT 'echo' <&0
	__rexec_cleanup
}

function __send_remote_file() {
	local fname=$1
	COLUMBIA_REXEC_FILE=/tmp/rexec_prep.$$.tmp
	COLUMBIA_REXEC_OUTPUT=/tmp/rexec_out.$$.tmp
	echo "RECEIVE_FILE#$fname#\n$(uuencode -m $fname -)___END_FILE___\n" > $COLUMBIA_REXEC_FILE
	RDC="$TOP/vendor/columbia/build/remote-dev-client.pl"
	$RDC $COLUMBIA_REXEC_FILE $COLUMBIA_REXEC_OUTPUT
	__rexec_cleanup
}

function r_adb() {
	if [ ! $COLUMBIA_REXEC_EN -eq 1 ]; then
		echo "Remote adb not supported in local mode"
		return;
	fi
	if [ "$1" = "push" ]; then
		__send_remote_file "$2"
	fi
	__perform_remote_cmd $_ADB $@
}

function r_cp() {
	__send_remote_file "$1" -v
	__perform_remote_cmd "echo \"Local file: $1\""
	D=$(cat $COLUMBIA_REXEC_OUTPUT)
	$E -e "\t$D"
}

function __reboot_to_fastboot() {
	local DEVS=
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__perform_remote_cmd "$_ADB devices | grep -v \"List of devices\" | \
			grep -v 'daemon not running' | grep -v 'daemon started' | \
			head -1 | sed -e 's/^\s*$//g' | awk '{print \$1}'"
		DEVS=$(cat $COLUMBIA_REXEC_OUTPUT)
	else
		DEVS=$($_ADB devices | grep -v "List of devices" | \
			grep -v 'daemon not running' | grep -v 'daemon started' | \
			sed -e 's/^\s*$//g' | awk '{print $1}')
	fi

	if [ -z "$DEVS" ]; then
		return
	fi

	RET=0
	for dev in $DEVS; do
		dev=$(echo $dev | sed 's/\s*//g')
		if [ ! -z "$dev" ]; then
			ans=Y
			if [ -z "$NO_AFLASH_REBOOT_CONF" ]; then
				$E -n "Reboot device '$dev'? [Y|n] "
				read ans
			fi
			if [ ! "n" = "$ans" -a ! "N" = "$ans" ]; then
				if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
					__perform_remote_cmd "$_ADB -s \"$dev\" reboot bootloader"
					cat $COLUMBIA_REXEC_OUTPUT
				else
					$_ADB -s "$dev" reboot bootloader
				fi
				RET=$?
			fi
		fi
	done
	return $RET
}

function kboot() {
	local _TPROD=$(get_build_var TARGET_PRODUCT)
	local TPROD=${_TPROD##*_}

	if [ -z "$TPROD" ]; then
		$E "You haven't chosen a lunch combo yet."
		return
	fi
	if [ ! -e "$_FB" ]; then
		$E "could not find fastboot in your path!"
		return
	fi

	__reboot_to_fastboot
	if [ $? -ne 0 ]; then return -1; fi

	local kdir=${ANDROID_ROOT}/$(get_build_var TARGET_OUT_INTERMEDIATES)/KERNEL

	local __fbopts=
	case "$TPROD" in
		passion) __fbopts="-b 0x20000000" ;;
		crespo) __fbopts="-b 0x30000000 -n 4096" ;;
		*) ;;
	esac

	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__send_remote_file "${kdir}/arch/arm/boot/zImage"
		__perform_remote_cmd "$_FB $__fbopts boot \"${kdir}/arch/arm/boot/zImage\""
		cat $COLUMBIA_REXEC_OUTPUT
	else
		$_FB $__fbopts boot "${kdir}/arch/arm/boot/zImage"
	fi
	return $?
}

function rfa() {
	if [ -z "$REPO__" ]; then
		__check_for_repo
		__rfa_usage
		return
	fi
	if [ "$1" = "-h" -o "$1" = "--help" ]; then
		__rfa_usage
		return
	fi

	$REPO__ forall -c "$E -e \"\n\033[0;32m \$REPO_PROJECT: \033[0m\"; eval \$@" eval $@
}

function cpimgs() {
	local DST=
	local TPROD=
	local FORCE=
	local CREATE_BOOT=
	local CP=$(which -a cp | grep -v "aliased to" | head -1)

	while [ 1 ]; do
	case "$1" in
		-f) FORCE="-f"
			shift;;
		-b) CREATE_BOOT="yes"
			shift;;
		-h|--help)
			$E "usage: cpimgs [-f|-b] {/path/to/destination {android_product_name}}"
			return;;
		*) break;;
	esac
	done

	DST=$1
	_TPROD=$(get_build_var TARGET_PRODUCT)
	TPROD=${2:-${_TPROD##*_}}

	if [ -z "$TPROD" ]; then
		TPROD=$ANDROID_DFLT_PRODUCT
	fi

	if [ -z "$DST" ]; then
		# attempt to use the currently chosen lunch combo + git branch!
		eval $PUSHD "$ANDROID_ROOT/build" > /dev/null
		local GIT_BRANCH=`git branch -a |grep "\->" | awk '{print $3}' | sed 's:.*/::'`
		$POPD >/dev/null
		DST="$TPROD/$TARGET_BUILD_VARIANT/$GIT_BRANCH"
	fi
	if [ ! -d "$DST" ]; then
		DST="$ANDROID_IMGS/$DST"
		mkdir -p "$DST" > /dev/null 2>&1
		__chk_err "creating destination: '$DST' check permissions?"
		if [ $? -ne 0 ]; then return -1; fi
	fi

	eval ANDROID_IMG_ROOT="${ANDROID_PRODUCT_OUT:-$ANDROID_ROOT/out/target/product/$TPROD}"
	eval ANDROID_RAMDISK="$ANDROID_IMG_ROOT/ramdisk.img"
	eval ANDROID_SYSIMG="$ANDROID_IMG_ROOT/system.img"
	eval ANDROID_USERIMG="$ANDROID_IMG_ROOT/userdata.img"
	eval ANDROID_RECOVERYIMG="$ANDROID_IMG_ROOT/recovery.img"
	eval ANDROID_BOOTIMG="$ANDROID_IMG_ROOT/boot.img"
	eval ANDROID_DATA="$ANDROID_IMGS/userdata-qemu.img"
	eval ANDROID_SDCARD="$ANDROID_IMGS/sdcard.img"
	kdir=${ANDROID_ROOT}/$(get_build_var TARGET_OUT_INTERMEDIATES)/KERNEL
	eval KERNEL_IMG="$kdir/arch/arm/boot/zImage"
	eval KERNEL_CFG="$kdir/.config"

	OTHERS="bootloader.bin flash.bct flash.cfg"

	$E "Copying images files from '$ANDROID_IMG_ROOT' to '$DST'..."
	eval $CP $FORCE "$ANDROID_RAMDISK" "$DST"
	eval $CP $FORCE "$ANDROID_SYSIMG" "$DST"
	eval $CP $FORCE "$ANDROID_USERIMG" "$DST"
	eval $CP $FORCE "$ANDROID_RECOVERYIMG" "$DST"
	eval $CP $FORCE "$ANDROID_BOOTIMG" "$DST"
	if [ -e "$KERNEL_IMG" ]; then
		eval $CP $FORCE "$KERNEL_IMG" "$DST/kernel-custom"
		if [ "$CREATE_BOOT" = "yes" ]; then
			BOOT_IMG="$DST/boot-custom.img"
			$E "Assuming kernel is: '$KERNEL_IMG'..."
			__mkbootimage "$KERNEL_IMG" "$ANDROID_RAMDISK" "$BOOT_IMG"
			__chk_err "creating boot image"
			if [ $? -ne 0 ]; then return -1; fi
			eval $CP $FORCE "$KERNEL_IMG" "$DST/kernel-custom"
		fi
	fi
	if [ -e "$KERNEL_CFG" ]; then
		eval $CP $FORCE "$KERNEL_CFG" "$DST/kernel-custom.config"
	fi

	for file in $OTHERS; do
		if [ -e "$ANDROID_IMG_ROOT/$file" ]; then
			eval $CP $FORCE "$ANDROID_IMG_ROOT/$file" "$DST"
		fi
	done
	eval touch "$ANDROID_DATA"
	eval touch "$ANDROID_SDCARD"
}

__aemu() {
	RUN_IN_BACKGROUND=0
	if [ "xbackground__" = "x$1" ]; then
		RUN_IN_BACKGROUND=1
		shift
	fi

	local ANDROID_IMG_ROOT=${1:-${ANDROID_IMGS}/${ANDROID_DFLT_IMGDIR}}
	shift

	local ANDROID_RAMDISK="$ANDROID_IMG_ROOT/ramdisk.img"
	local ANDROID_SYSIMG="$ANDROID_IMG_ROOT/system.img"
	local ANDROID_USERIMG="$ANDROID_IMG_ROOT/userdata.img"
	local ANDROID_DATA="$ANDROID_IMGS/userdata-qemu.img"
	local ANDROID_SDCARD="$ANDROID_IMGS/sdcard.img"
	local ANDROID_SKINDIR="$ANDROID_ROOT/sdk/emulator/skins"
	local DFLT_SKIN="HVGA"

	local CMD="$ANDROID_HOST_BIN/emulator"
	local OPTS="-sysdir $ANDROID_IMG_ROOT -data $ANDROID_DATA -sdcard $ANDROID_SDCARD -skindir $ANDROID_SKINDIR -skin $DFLT_SKIN -memory 512 -partition-size 256 -verbose -show-kernel $@"
	$E "Executing: $CMD $OPTS "
	unset ANDROID_PRODUCT_OUT
	if [ $RUN_IN_BACKGROUND = 1 ]; then
		$CMD $OPTS &
	else
		$CMD $OPTS
	fi
}

__tree_aemu() {
	RUN_IN_BACKGROUND=0
	if [ "xbackground__" = "x$1" ]; then
		RUN_IN_BACKGROUND=1
		shift
	fi

	local PRODUCT=${1:-${ANDROID_DFLT_PRODUCT}}
	shift

	local ANDROID_IMG_ROOT="${ANDROID_PRODUCT_OUT:-$ANDROID_ROOT/out/target/product/$PRODUCT}"
	local ANDROID_RAMDISK="$ANDROID_IMG_ROOT/ramdisk.img"
	local ANDROID_SYSIMG="$ANDROID_IMG_ROOT/system.img"
	local ANDROID_USERIMG="$ANDROID_IMG_ROOT/userdata.img"
	local ANDROID_DATA="$ANDROID_SDK/userdata-qemu.img"
	local ANDROID_SDCARD="$ANDROID_SDK/sdcard.img"
	local ANDROID_SKINDIR="$ANDROID_ROOT/sdk/emulator/skins"
	local DFLT_SKIN="HVGA"

	local CMD="$ANDROID_HOST_BIN/emulator"
	local OPTS="-sysdir $ANDROID_IMG_ROOT -data $ANDROID_DATA -sdcard $ANDROID_SDCARD -skindir $ANDROID_SKINDIR -skin $DFLT_SKIN -memory 512 -partition-size 256 -verbose -show-kernel $@"
	#OPTS="-ramdisk $ANDROID_RAMDISK -system $ANDROID_SYSIMG -sdcard $ANDROID_SDCARD -initdata $ANDROID_USERIMG -data $ANDROID_DATA -memory 512 -partition-size 256 -verbose -show-kernel $@"
	$E "Executing: $CMD $OPTS "
	if [ $RUN_IN_BACKGROUND = 1 ]; then
		$CMD $OPTS &
	else
		$CMD $OPTS
	fi
}

__emu_usage() {
	$E -e "usage: emu [-b|-tree|-k|-imgs]"
	$E -e "\t-b     : Run in the background"
	$E -e "\t-tree  : Run emulator using Android tree images"
	$E -e "\t         (not a custom images directory)"
	$E -e "\t-k     : Pass '-kernel \$ANDROID_KERNEL_DIR/arch/arm/boot/zImage'"
	$E -e "\t         to emulator."
	$E -e "\t-imgs [/path/to/cpimgs/output]"
	$E -e "\t       : boot emulator using provided images (not default)"
	$E -e "\t         (accepts paths relative to \$ANDROID_IMGS, and"
	$E -e "\t         respects your lunch combo!)"
	$E ""
}

function emu() {
	local TREE=0
	local B=
	local KOPT=
	local IMGS=
	while [ 1 ]; do
	case "$1" in
		-tree) TREE=1
			shift;;
		-b) B="background__"
			shift;;
		-k) KOPT="-kernel $ANDROID_KERNEL_DIR/arch/arm/boot/zImage"
			shift;;
		-imgs) IMGS="$2"
			shift
			shift;;
		-h|--help) __emu_usage
			return;;
		*) break;;
	esac
	done

	local _PROD=$(get_build_var TARGET_PRODUCT)
	local PRODUCT=${_PROD##*_}
	if [ -z "$PRODUCT" ]; then
		PRODUCT="$ANDROID_DFLT_PRODUCT"
	fi

	if [ -z "$IMGS" ]; then
		IMGS="${ANDROID_IMGS}/${ANDROID_DFLT_IMGDIR}"
	fi
	if [ ! -d "$IMGS" ]; then
		IMGS="${ANDROID_IMGS}/$IMGS"
	fi

	if [[ $TREE > 0 ]]; then
		__tree_aemu $B ${PRODUCT} $KOPT $@
	else
		__aemu $B "$IMGS" $KOPT $@
	fi
}

__aflash_usage() {
	$E -e "usage: aflash [-b|-k|-imgs]"
	$E -e "\t-b                      : flash only the boot partition"
	$E -e "\t-nb                     : SKIP flashing the boot partition"
	$E -e "\t-nr                     : SKIP the automatic device reboot after flashing"
	$E -e "\t-k                      : Flash the most recent kernel built in \$ANDROID_KERNEL_DIR"
	$E -e "\t-kk [/path/to/kernel]   : path to the kernel image (or directory)"
	$E -e "\t-imgs [/path/to/imgdir] : path to a directory containing compiled"
	$E -e "\t                          Android images (defaults to \$ANDROID_PRODUCT_OUT)"
	$E -e "\t-stock                  : use 'boot.img' instead of any custom boot"
	$E -e "\t                          image which may be in the images directory"
	$E -e "\t--remote                : Use a tunneled connection to a remote host where"
	$E -e "\t                          the actual execution will take place."
	$E -e "\t                          NOTE: in order for this to work, you need to use the"
	$E -e "\t                                remote-dev-server.pl script..."
	$E -e "\t                                (this is not well-supported)"
	$E -e "\n"
}

function aflash() {

	local KPATH=
	local IMGPATH=
	local ONLYBOOT=0
	local NOBOOT=0
	local BOOT_IMG=
	local FORCE_STD_BOOT=0
	local NO_REBOOT=0
	local _TPROD=$(get_build_var TARGET_PRODUCT)
	local TPROD=${_TPROD##*_}

	local ERASE_CMD=erase
	local _FB_HAS_FMT="$(fastboot -h 2>&1 | grep "format <partition>")"
	if [ ! -z "${_FB_HAS_FMT}" ]; then
		ERASE_CMD=format
	fi

	while [ 1 ]; do
	case "$1" in
		-b) ONLYBOOT=1
			shift;;
		-nb) NOBOOT=1
			shift;;
		-nr) NO_REBOOT=1
			shift;;
		-k) KPATH="${ANDROID_ROOT}/$(get_build_var TARGET_OUT_INTERMEDIATES)/KERNEL/arch/$(get_build_var TARGET_ARCH)/boot/zImage"
			shift;;
		-kk) eval KPATH=$2
			shift
			shift;;
		-stock) FORCE_STD_BOOT=1
			shift;;
		-imgs) eval IMGPATH="$2"
			# if we specify an image path - respect a pre-existing
			# boot image that we created!
			if [ -e "$IMGPATH/boot-custom-${TPROD}.img" ]; then
				eval BOOT_IMG="$IMGPATH/boot-custom-${TPROD}.img"
			fi
			shift
			shift;;
		-h|--help) __aflash_usage
			return 0;;
		*) break;;
	esac
	done

	__reboot_to_fastboot
	if [ $? -ne 0 ]; then return -1;
	else sleep 2; fi

	if [ $NOBOOT -eq 1 ]; then
		KPATH=
		FORCE_STD_BOOT=0
	fi

	# if no specific image path is given, use the image
	# in the current build directory
	if [ -z "$IMGPATH" ]; then
		IMGPATH=${ANDROID_ROOT}/$(get_build_var PRODUCT_OUT)
	fi

	if [ ! -e "$_FB" ]; then
		$E "could not find fastboot in your path!"
		return -1
	fi
	if [ ! -d "$IMGPATH" ]; then
		BOOT_IMG=
		IMGPATH="${ANDROID_PRODUCT_OUT:-$ANDROID_ROOT/out/target/product/${TPROD:-$ANDROID_DFLT_PRODUCT}}"
		$E "Looking for images in '$IMGPATH'/..."
	fi

	local SYSTEM_IMG="$IMGPATH/system.img"
	local RAMDISK_IMG="$IMGPATH/ramdisk.img"

	if [ $FORCE_STD_BOOT -gt 0 ]; then
		BOOT_IMG="$IMGPATH/boot.img"
	fi
	if [ -z "$BOOT_IMG" ]; then
		BOOT_IMG="$IMGPATH/boot.img"
	fi

	if [ $NOBOOT -eq 1 ]; then
		$E -e "\033[0;32mSkipping boot flash\033[0m"
	elif [ ! -z "$KPATH" ]; then
		if [[ ! "$BOOT_IMG" =~ ".*boot\-custom-$TPROD\.img" ]]; then
			BOOT_IMG=${BOOT_IMG/.img/-custom-${TPROD}.img}
		fi
		if [ -d "$KPATH" ]; then
			KPATH="$KPATH/arch/arm/boot/zImage"
		fi
		$E "Creating custom boot image..."
		$E "Using kernel in: '$KPATH'"
		__mkbootimage "$KPATH" "$RAMDISK_IMG" "$BOOT_IMG"
		__chk_err "creating boot image!"
		if [ $? -ne 0 ]; then return -1; fi
		if [ $FORCE_STD_BOOT -gt 0 ]; then
			$E "Ignoring fresh custom boot image: using stock (as requested)"
			BOOT_IMG="${IMGPATH}/boot.img"
		fi
		$E -e "\033[0;32mFlashing '$BOOT_IMG'...\033[0m"
		if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
			__send_remote_file "$BOOT_IMG"
			__perform_remote_cmd "$_FB flash boot $BOOT_IMG"
			cat $COLUMBIA_REXEC_OUTPUT
		else
			eval $_FB flash boot "$BOOT_IMG"
		fi
		if [ $? -ne 0 ]; then
			$E "ERROR flashing boot!"
			return -1
		fi
	elif [ -e "$BOOT_IMG" ]; then
		$E -e "\033[0;32mFlashing '$BOOT_IMG'...\033[0m"
		if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
			__send_remote_file "$BOOT_IMG"
			__perform_remote_cmd "$_FB flash boot $BOOT_IMG"
			cat $COLUMBIA_REXEC_OUTPUT
		else
			eval $_FB flash boot "$BOOT_IMG"
		fi
		if [ $? -ne 0 ]; then
			$E "ERROR flashing boot!"
			return -1
		fi
	fi

	if [ $ONLYBOOT -gt 0 ]; then
		$E -e "\033[0;31mFlashing (only boot) Complete.\033[0m"
		if [ ! $NO_REBOOT -gt 0 ]; then
			$E -e "\033[0;31m    Rebooting...\033[0m"
			if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
				__perform_remote_cmd "$_FB reboot"
				cat $COLUMBIA_REXEC_OUTPUT
			else
				$_FB reboot
			fi
		fi
		return $?
	fi

	if [ ! -e "$IMGPATH/system.img" ]; then
		$E "ERROR: Could not find system.img in '$IMGPATH'"
		$E "usage: droidflash /path/to/images {/path/to/kernel}"
		return -1
	fi

	# system image
	$E -e "\033[0;32mFlashing '$SYSTEM_IMG'...\033[0m"
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__send_remote_file "$SYSTEM_IMG"
		__perform_remote_cmd "$_FB flash system $SYSTEM_IMG"
		cat $COLUMBIA_REXEC_OUTPUT
	else
		eval $_FB flash system "$SYSTEM_IMG"
	fi
	if [ $? -ne 0 ]; then
		$E "ERROR flashing system!"
		return -1
	fi

	# Just erase/format the userdata for now
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__perform_remote_cmd "$_FB ${ERASE_CMD} userdata"
	else
		eval $_FB ${ERASE_CMD} userdata
	fi

	# clear cache partition
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__perform_remote_cmd "$_FB ${ERASE_CMD} cache"
		cat $COLUMBIA_REXEC_OUTPUT
	else
		eval $_FB ${ERASE_CMD} cache
	fi
	if [ $? -ne 0 ]; then
		$E "WARNING: problem erasing cache partition"
	fi

	local _msg=
	if [ $NO_REBOOT -gt 0 ]; then
		_msg="Flashing Complete."
	else
		_msg="Flashing Complete: Rebooting..."
	fi
	$E -e "\033[0;31m${_msg}\033[0m"
	if [ ! $NO_REBOOT -gt 0 ]; then
		if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
			__perform_remote_cmd "$_FB reboot"
			cat $COLUMBIA_REXEC_OUTPUT
		else
			$_FB reboot
		fi
	fi
	return 0
}

__apush_usage() {
	$E -e "usage: apush [-h] [sysdir] [path-glob] {dst_dir}"
	$E -e "\t-h          : show this help screen"
	$E -e "\t[sysdir]    : directory under \$TOP/out/target/product/\$TARGET_PRODUCT/"
	$E -e "\t              to search for [path-glob]"
	$E -e "\t              e.g. system/bin"
	$E -e "\t[path-glob] : path(s) to file(s) to push"
	$E -e "\t              e.g. \"*cell*\""
	$E -e "\t{dst_dir}   : optional parameter to specify the directory on"
	$E -e "\t              the device into which [path-glob] will be placed"
	$E -e "Example:"
	$E -e "    To push all files in \$TOP/out/target/product/\$TARGET_PRODUCT/system/bin"
	$E -e "    whose file names contain 'ril' (e.g. libril.so) onto the sdcard of the device"
	$E -e "    you would do:"
	$E -e "        apush system/bin \"*ril*\" /sdcard"
	$E ""
}

function apush() {
	local SYSDIR=${1:-system/bin}
	local PATH_GLOB=${2:-*cell*}
	local DSTDIR=$3

	if [ "$SYSDIR" = "-h" -o "$SYSDIR" = "--help" ]; then
		__apush_usage
		return -1
	fi

	local DIR=
	local FILES=
	local WC=
	eval DIR="${ANDROID_ROOT}/$(get_build_var PRODUCT_OUT)"
	eval FILES=$($__LS -1d $DIR/$SYSDIR/$PATH_GLOB)
	WC=`echo "$FILES" | wc -w`
	if [ "$WC" -gt "50" ]; then
		$E "There are a lot ($WC) of files in this list:"
		$E -n "Do you want to push them all? [Y|n] "
		$E -e "\033[0;33m$FILES\033[0m"
		read ans
		if [ "$ans" = "n" -o "$ans" = "N" -o "$ans" = "no" ]; then
			$E "goodbye"
			return -1
		fi
	fi

	local D="${DSTDIR:-/$SYSDIR}"

	$E -e "Remounting read-write..."
	if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
		__perform_remote_cmd "$_ADB remount"
	else
		$_ADB remount
	fi

	$E -e "Moving files from \033[0;33m$DIR/$SYSDIR/$PATHGLOB\033[0m to \033[0;33m$D\033[0m..."
	for f in $FILES; do
		$E -e "    \033[0;32m$f -> $D/${f##*/}\033[0m"
		if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
			__send_remote_file "$f"
			__perform_remote_cmd "$_ADB push $f $D/${f##*/}"
		else
			$_ADB push $f $D/${f##*/}
		fi
	done
	return $?
}

if [[ $ADD_PREBUILT_TOOLCHAIN_TO_PATH = 1 ]]; then
	# make sure it's not already there
	__toolpath=$(echo $PATH | sed "s#.*:*\(${ARM_EABI_TOOLCHAIN}[^:]*\).*#\1#")
	if [ "$__toolpath" != "${ARM_EABI_TOOLCHAIN}" ]; then
		echo "adding ${ARM_EABI_TOOLCHAIN} to your path..."
		eval export PATH="$ARM_EABI_TOOLCHAIN/bin:$PATH"
	fi
fi
if [[ $ADD_ANDROID_HOST_BIN_TO_PATH = 1 ]]; then
	__toolpath=$(echo $PATH | sed "s#.*:*\(${ANDROID_HOST_BIN}[^:]*\).*#\1#")
	if [ "$__toolpath" != "${ANDROID_HOST_BIN}" ]; then
		echo "adding ${ANDROID_HOST_BIN} to your path..."
		eval export PATH="$ANDROID_HOST_BIN:$PATH"
	fi
fi

# check for repo down here (i.e. _after_ we've added to the path!)
__check_for_repo

export _ADB=$(which -a adb | grep -v "aliased to" | head -1)
export _FB=$(which -a fastboot | grep -v "aliased to" | head -1)
export _ARM_GDB=$(which -a arm-linux-androideabi-gdb | grep -v "aliased to" | head -1)
if [ -z "$_ARM_GDB" ]; then
	export _ARM_GDB=$(which -a arm-eabi-gdb | grep -v "aliased to" | head -1)
fi

if [ $COLUMBIA_REXEC_EN -eq 1 ]; then
	$E "Preparing for remote execution..."
	__prep_remote_server
fi
