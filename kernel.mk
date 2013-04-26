#
# Linux kernel Android makefile
# Copyright (C) 2011-2013 Jeremy C. Andrus
#
# This file defines Android build targets that invoke the Linux kernel
# build system. The SOP here at Columbia has been to create a defconfig
# that matches your lunch combo, e.g. "full_grouper_defconfig" or
# "full_crespo_defconfig" This configuration is invoked as a dependency
# to ensure a properly configured kernel for each build.
#
# Installation:
# (1) In your device specific directory (e.g. $TOP/device/asus/grouper) add
#     a file named "Android.mk" and put the following line in it:
#     include vendor/columbia/build/kernel.mk
# (2) In the same device specific directory, remove all references to the
#     LOCAL_KERNEL, TARGET_PREBUILT_KERNEL, and TARGET_PREBUILT_WIFI_MODULE
#     variables. Be sure to remove any "$(LOCAL_KERNEL):kernel" lines from
#     the PRODUCT_COPY_FILES variable. This info is generally found in a
#     file names similarly to: "device-common.mk"
# (3) [OPTIONAL]
#     In the product configuration file, e.g., device.mk, you can add the following
#     line to load product-specific packages from the "columbia.mk" file:
#     $(call inherit-product-if-exists, vendor/columbia/build/grouper/device-vendor.mk)
#

ifneq ($(TARGET_NO_KERNEL),true)

__kernel_defconfig := $(TARGET_PRODUCT)_defconfig
__kernel_obj := ${ANDROID_ROOT}/$(TARGET_OUT_INTERMEDIATES)/KERNEL
__kernel_src := ${ANDROID_ROOT}/kernel
__kernel_modpath := ${ANDROID_ROOT}/$(TARGET_OUT_INTERMEDIATES)/KERNEL_MODULES
__target_modpath := ${ANDROID_ROOT}/$(TARGET_OUT)/modules
#${ANDROID_ROOT}/$(PRODUCT_OUT)/modules

KERNEL_CONFIG := $(__kernel_obj)/.config
KERNEL_ZIMAGE := $(__kernel_obj)/arch/$(TARGET_ARCH)/boot/zImage

define kbuild
$(MAKE) -C $(__kernel_src) \
	ARCH=$(TARGET_ARCH) \
	CROSS_COMPILE=${ANDROID_CROSS_COMPILE} \
	O=$(__kernel_obj) \
	INSTALL_MOD_PATH=$(__kernel_modpath) \
	$(if $(SHOW_COMMANDS),V=1)
endef

$(KERNEL_CONFIG): $(__kernel_src)/arch/$(TARGET_ARCH)/configs/$(__kernel_defconfig)
	@echo "Configuring kernel for $(TARGET_ARCH): ($(__kernel_defconfig))..."
	@mkdir -p $(__kernel_obj) 2>/dev/null
	+$(hide) $(kbuild) $(__kernel_defconfig)

# force this to build just to be safe...
$(KERNEL_ZIMAGE): $(KERNEL_CONFIG) FORCE
	@echo "Building Linux kernel..."
	@mkdir -p $(__kernel_obj) 2>/dev/null
	+$(hide) $(kbuild) zImage

$(INSTALLED_KERNEL_TARGET): $(KERNEL_ZIMAGE) | $(ACP)
	$(copy-file-to-target)

# the kernel modules target
#
# we have to force b/c there's no way to "divine"
# which modules will be installed (and I'm not going
# to write a kconfig parser to do it)
kmodules: $(KERNEL_ZIMAGE) FORCE
	@echo "Building kernel modules"
	@mkdir -p $(__kernel_modpath)
	@mkdir -p $(__target_modpath) 2>&1 >/dev/null
	+$(hide) $(kbuild) modules
	+$(hide) $(kbuild) modules_install
	@find $(__kernel_modpath)/lib/modules/$(strip $(shell cat $(__kernel_obj)/include/config/kernel.release)) -name *.ko -exec cp -v {} $(__target_modpath) \;

# the kernel target
#
kernel: $(INSTALLED_KERNEL_TARGET) kmodules bootimage

# Let's make the system.img target depend on the kernel
# target so that modules will be auto-magically included!
__kernel_sysimg_tgt := $(call intermediates-dir-for,PACKAGING,systemimage)/system.img

$(__kernel_sysimg_tgt): kernel

TARGET_PREBUILT_KERNEL := $(KERNEL_ZIMAGE)

# This is a bit of a hack, but should get the WIFI module in place...
# NOTE: I think this is deprecated... the kmodules target should put everything in place!
TARGET_PREBUILT_WIFI_MODULE := $(shell find $(__kernel_modpath) -name '*.ko' | grep "drivers/net/wireless" | xargs basename)

.PHONY: kernel kmodules

endif # !TARGET_NO_KERNEL

