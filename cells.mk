#
# Columbia Cells product-specific Android build file
# Copyright (C) 2013 Jeremy C. Andrus
#

# custom cells packages
PRODUCT_PACKAGES := \
	aufs.ko \
	cell \
	celld \
	cells_bootanimation \
	busybox \
	Nucleus

# Filesystem management tools
 PRODUCT_PACKAGES += \
	make_ext4fs \
	setup_fs

# we have enough storage space to hold precise GC data
PRODUCT_TAGS += dalvik.gc.type-precise

PRODUCT_PROPERTY_OVERRIDES += \
	persist.security.efs.enabled=0

# inherit from the proprietary Google apps target, if present
$(call inherit-product-if-exists, vendor/columbia/external/gapps/gapps.mk)
