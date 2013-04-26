Columbia SSL Android Build Configuration
==========
This repository is the result of several years of Android development where
more than just applications need to be built and manipulated. Here we provide
a mechanism to integrate the Linux kernel build into a system.img build, as
well as several handy shell functions that wrap up some building/flashing
functionality.

Kernel Build Integration
==========
1. In your device specific directory (e.g. $TOP/device/asus/grouper) add
a file named <em>Android.mk</em> and put the following line in it:
<em>include vendor/columbia/build/kernel.mk</em>
2. In the same device specific directory, remove all references to the
<b>LOCAL_KERNEL</b>, <b>TARGET_PREBUILT_KERNEL</b>, and
<b>TARGET_PREBUILT_WIFI_MODULE</b> variables. Be sure to remove any
<em>$(LOCAL_KERNEL):kernel</em> lines from the <b>PRODUCT_COPY_FILES</b>
variable. This info is generally found in a file names similarly to:
<em>device-common.mk</em>
3. <em>[OPTIONAL]</em><br>
In the product configuration file, e.g., device.mk, you can add the following
line to load product-specific packages from the "columbia.mk" file:
<em>$(call inherit-product-if-exists, vendor/columbia/build/grouper/device-vendor.mk)</em>

Installation / Configuration
==========
After setting up a small number of environment variables (described below)
simply source this file directly and pass the lunch combo as an argument.<br>
e.g.<br>
<em>user@host$ source ./android-env.sh full_grouper-eng</em>

Optional arguments: (before the lunch combo)

	-nosrc    : Don't invoke "lunch" and don't expect the Android sources
	            to be present. This can be handy if you just want a shell
	            environment without having an entire Android tree.
	
	-remote   : Experimental (highly untested) remote environment
	            (allows limited use of this environment from a remote machine)

Variables: (prompts if not found)
----------
	ANDROID_ROOT : root of the Android source tree
	
	ANDROID_IMGS : path to directory which will be used to archive images
	             : also the location of userdata-qemu.img and sdcard.img
	             : emulator images
	
	ANDROID_KERNEL_DIR : directory containing the Android kernel source

	[deprecated - to be removed soon...]
	ANDROID_DFLT_IMGDIR : default directory to look for system.img, userdata.img,
	                    : etc. - must be a subdirectory of ANDROID_IMGS!
	
	[deprecated - to be removed soon...]
	ANDROID_DFLT_PRODUCT : default product output directory to use
	                     : (e.g. generic, or passion)

Optional variables
----------
	ADD_ANDROID_HOST_BIN_TO_PATH   : add the host binary output to your path
	                               : defaults to 1 (pretty useful)
	
	ADD_PREBUILT_TOOLCHAIN_TO_PATH : add the prebuilt ARM toolchain to your path
	                               : defaults to 1

Shell Commands
----------

### kbuild
Kernel cross-compilation wrapper

Compilation output is set to Android platform object directory
(currently: <em>out/target/product/{poduct_name}/obj/KERNEL</em>)

Usage:

	kbuild [options] [make parameters]
	                 -h|--help           shows this text
	                 --pincc[=prefix]    sets CROSS_COMPILE=prefix
	                                     (defaults to $cc_cross)
	                 [make parameters]  parameters passed directly to make

### kconfig
Configure the Linux kernel for ARM processors

Usage:

	kconfig

### kmodules
Build and install the Android Linux kernel modules

Usage:

	kmodules

### kboot
Boot a custom kernel on a device (via fastboot)

Note: have your phone/device plugged in and in fastboot mode

<b>WARNING</b> This doesn't work with all devices...

Usage:

	kboot

### aflash
Flash a set of images onto a device

Usage:

	aflash /path/to/images {/path/to/kernel}
	aflash [-b|-k|-imgs]
	           -b                      : flash only the boot partition
	           -nb                     : SKIP flashing the boot partition
	           -k [/path/to/kernel]    : path to the kernel image (or directory)
	           -stock                  : Use boot.img (the stock) _not_ a custom
	                                     built boot image
	           -imgs [/path/to/imgdir] : path to a directory containing compiled
	                                     Android images (defaults to $ANDROID_PRODUCT_OUT)

Note: If you pass the optional kernel path, it can be to the zImage, or
to the top-level dir where 'arch/arm/boot/zImage' can be found.

### apush
Push some files to an android device via adb

Usage:

	apush [-h] [system_dir] [file-glob] {dest}
	            -h          : show this help screen
	            [sysdir]    : directory under \$TOP/out/target/product/\$TARGET_PRODUCT/
	                          to search for [path-glob]
	                          e.g. bin
	            [path-glob] : path(s) to file(s) to push
	                          e.g. \"*cell*\"
	            {dst_dir}   : optional parameter to specify the directory on
	                          the device into which [path-glob] will be placed
	Example:
	    To push all files in \$TOP/out/target/product/\$TARGET_PRODUCT/system/bin
	    whose file names contain 'ril' (e.g. libril.so) onto the sdcard of the device
	    you would do:
	        apush system/bin \"*ril*\" /sdcard

Note: This utility will push a (set of) file(s) to an android device.
It assumes that the files you are looking for can be found in:
$TOP/out/target/product/${TARGET_DEVICE}/(system_dir)
and can be found using an ls command in the above directory using
the provided file (glob)

File globs should be enclosed in quotes to prevent your shell
from expanding them.

### rfa
Run 'repo forall -c' in a more user-friendly way

Usage:

	rfa [-h] command arg1 arg2...

### cpimgs
Copy the relevant output images from an android compilation

Note: accepts paths relative to <b>$ANDROID_IMGS</b>

Usage:

	cpimgs [-h] /path/to/image_destination {android_product_name}

### emu
Run the Android emulator

Note: this hasn't been tested for a while...

Note: this uses the stock kernel by default, please pass a -kernel option
to boot a custom kernel (or the -k option for: -kernel arch/arm/boot/zImage)

Usage:

	emu [-b|-tree|-k|-imgs /images/path] {additional emulator parameters}
	        -b     : Run in the background
	        -tree  : Run emulator using Android tree images (not a custom images directory)
	        -k     : Pass '-kernel $ANDROID_KERNEL_DIR/arch/arm/boot/zImage' to emulator
	        -imgs [/path/to/cpimgs/output] : boot emulator using provided images (not default)
	                                         (accepts paths relative to $ANDROID_IMGS, and
	                                          respects your lunch combo!)
	        All other parameters are passed directory to the Android 'emulator'
	        binary program
	
