# XLR x86_64 Virtual Machin

ONIE_ARCH ?= x86_64

VENDOR_REV ?= 0


# Translate hardware revision to ONIE hardware revision
ifeq ($(VENDOR_REV),0)
  MACHINE_REV = 0
else
  $(warning Unknown VENDOR_REV '$(VENDOR_REV)' for MACHINE '$(MACHINE)')
  $(error Unknown VENDOR_REV)
endif

# Vendor ID -- IANA Private Enterprise Number:
# http://www.iana.org/assignments/enterprise-numbers
# Open Compute Project IANA number
VENDOR_ID = 4413

SWITCH_ASIC_VENDOR = bcm
# Add the onie-syseeprom command for this platform
PARTED_ENABLE = yes

PARTITION_TYPE = gpt

I2CTOOLS_ENABLE = yes

CONSOLE_SPEED ?= 115200

# Set Linux kernel version

#LINUX_VERSION = 4.9
#LINUX_MINOR_VERSION = 95
LINUX_VERSION = 4.19
LINUX_MINOR_VERSION = 143


# Specify uClibc version

#xlr board support UEFI
UEFI_ENABLE = yes

#-------------------------------------------------------------------------------
#
# Local Variables:
# mode: makefile-gmake
# End:
