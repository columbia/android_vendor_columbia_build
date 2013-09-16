# Include device-independent makefile
include vendor/columbia/build/cells.mk

# include any device-dependent files / packages here...
PRODUCT_COPY_FILES += \
	vendor/columbia/build/grouper/init.grouper.cell.rc:system/etc/cells/init.grouper.rc \
	vendor/columbia/build/grouper/init.grouper.rc:root/init.grouper.rc
