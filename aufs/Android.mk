#
# Aufs automagic kernel module build
# Copyright (C) 2011-2013 Jeremy C. Andrus
#
# IMPORTANT: the kernel needs to have been configured/compiled
#
# This is a bit hack-ish as it bypasses the standard Android makefile system,
# but I don't mind that because it lets me leave the aufs Makefile alone...
#

AUFS_PATH ?= vendor/columbia/external/aufs

# don't build this unless the module path exists!
ifeq (buildaufs, $(shell [ -d ${ANDROID_ROOT}/$(AUFS_PATH) ] && echo buildaufs))

#
# The Android target will act like a
# prebuilt module that actually gets
# compiled "just-in-time"
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := aufs.ko
LOCAL_MODULE_CLASS := KERNEL_MODULES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_PATH := $(TARGET_OUT)/modules
LOCAL_UNSTRIPPED_PATH := $(TARGET_OUT)/modules

# we have to do this to put the module on the "whitelist"
# of approved sources to be included automatically
LOCAL_MODULE_OWNER := google

include $(BUILD_PREBUILT)

### ### ### ###
### Hook in the building of a kernel module through non-Android build system
###

KPATH ?= ${ANDROID_ROOT}/kernel
KOBJ_DIR ?= ${ANDROID_ROOT}/$(TARGET_OUT_INTERMEDIATES)/KERNEL
KODIR = KOBJ_DIR=$(KOBJ_DIR)

# Aufs module paths
BUILT_AUFSMOD_TARGET := $(AUFS_PATH)/aufs.ko
PREBUILT_AUFS_TARGET := $(call local-intermediates-dir)/aufs.ko

# Disable automatic git checkout... handle this at the Android Manifest level
#define aufs-mod-build
#	@echo "Checking out aufs2.1-$(KVER)..."
#	@git --work-tree="$(AUFSMOD_SRC)" \
#		--git-dir="$(AUFSMOD_SRC)/.git" checkout aufs2.1-$(KVER)
#	@echo "Now building..."
#	$(MAKE) ARCH=$(TARGET_ARCH) CROSS_COMPILE=arm-eabi- $(KODIR) \
#		-C $(AUFSMOD_SRC) KDIR=$(KPATH) $(if $(SHOW_COMMANDS),V=1) $1
#endef
define aufs-mod-build
$(MAKE) ARCH=$(TARGET_ARCH) CROSS_COMPILE=${ANDROID_CROSS_COMPILE} $(KODIR) \
	-C $(AUFSMOD_SRC) KDIR=$(KPATH) $(if $(SHOW_COMMANDS),V=1) $1
endef

#$(BUILT_AUFSMOD_TARGET): KSUBLVL := $(shell grep "SUBLEVEL =" "$(KPATH)/Makefile")
#$(BUILT_AUFSMOD_TARGET): KVER := $(subst SUBLEVEL = ,,$(KSUBLVL))
$(BUILT_AUFSMOD_TARGET): AUFSMOD_SRC := ${ANDROID_ROOT}/$(AUFS_PATH)
$(BUILT_AUFSMOD_TARGET): FORCE
	@echo "[AUFS] --> Module clean"
	+$(hide) $(aufs-mod-build) clean
	@echo "[AUFS] --> Module build"
	+$(hide) $(aufs-mod-build) aufs.ko
	@mkdir -p $(shell dirname $(PREBUILT_AUFS_TARGET))
	@cp -v $(BUILT_AUFSMOD_TARGET) $(PREBUILT_AUFS_TARGET)

# "The Magic"
# Add dependencies to our local "prebuilt" module
# which essentially build the module "just-in-time" :-)
#
$(BUILT_AUFSMOD_TARGET): kernel kmodules
$(LOCAL_MODULE) $(LOCAL_BUILT_MODULE): $(BUILT_AUFSMOD_TARGET)

# Let's make the system.img target
# depend on the aufs target so that the module will be
# auto-magically included in the final image!
___sysimg_tgt := $(call intermediates-dir-for,PACKAGING,systemimage)/system.img
$(___sysimg_tgt): $(LOCAL_MODULE)

endif # aufs module path exists
