#!/bin/bash

#######################################################################################
# Magisk Boot Image Patcher
#######################################################################################
#
# Usage: boot_patch.sh <bootimage>
#
# The following environment variables can configure the installation:
# KEEPVERITY, KEEPFORCEENCRYPT, PATCHVBMETAFLAG, RECOVERYMODE, LEGACYSAR
#
# This script should be placed in a directory with the following files:
#
# File name          Type      Description
#
# boot_patch.sh      script    A script to patch boot image for Magisk.
#                  (this file) The script will use files in its same
#                              directory to complete the patching process.
# magiskinit         binary    The binary to replace /init.
# magisk32           binary    The magisk binaries.
# magisk64           binary    The magisk binaries.
# magiskboot         binary    A tool to manipulate boot images.
# stub.apk           binary    The stub Magisk app to embed into ramdisk.
#
#######################################################################################

############
# Functions
############

# Pure bash dirname implementation
getdir() {
  case "$1" in
    */*)
      dir=${1%/*}
      if [ -z "$dir" ]; then
        echo "/"
      else
        echo "$dir"
      fi
    ;;
    *) echo "." ;;
  esac
}

ui_print() {
  echo "$1"
}

abort() {
  ui_print "$1"
  exit 1
}

#################
# Initialization
#################

if [ -z "$SOURCEDMODE" ]; then
  # Switch to the location of the script file
  cd "$(getdir "${BASH_SOURCE:-$0}")"
fi

BOOTIMAGE="$1"
[ -e "$BOOTIMAGE" ] || abort "$BOOTIMAGE does not exist!"

# Check for command dependencies
command -v magiskboot >/dev/null 2>&1 || abort "magiskboot not found!"
command -v nanddump >/dev/null 2>&1 || abort "nanddump not found!"
command -v grep_prop >/dev/null 2>&1 || abort "grep_prop not found!"

# Dump image for MTD/NAND character device boot partitions
if [ -c "$BOOTIMAGE" ]; then
  if ! nanddump -f boot.img "$BOOTIMAGE"; then
    abort "! Failed to dump boot image from device"
  fi
  BOOTNAND="$BOOTIMAGE"
  BOOTIMAGE=boot.img
fi

# Check for image format
if ! file "$BOOTIMAGE" | grep -q "DOS/MBR boot sector"; then
  abort "! Unsupported/Unknown image format"
fi

# Flags
: "${KEEPVERITY:=false}"
: "${KEEPFORCEENCRYPT:=false}"
: "${PATCHVBMETAFLAG:=false}"
: "${RECOVERYMODE:=false}"
: "${LEGACYSAR:=false}"
export KEEPVERITY KEEPFORCEENCRYPT PATCHVBMETAFLAG RECOVERYMODE LEGACYSAR

chmod -R 755 .

#########
# Unpack
#########

CHROMEOS=false

ui_print "- Unpacking boot image"

if ! ./magiskboot unpack "$BOOTIMAGE"; then
  abort "! Failed to unpack boot image"
fi

case $? in
  0 ) ;;
  1 )
    ui_print "- ChromeOS boot image detected"
    CHROMEOS=true
    ;;
  * )
    abort "! Failed to unpack boot image"
    ;;
esac

# Check for ramdisk format
if [ ! -f ramdisk.cpio ]; then
  abort "! Unsupported/Unknown ramdisk format"
fi

###################
# Ramdisk Restores
###################

# Test patch status and do restore
ui_print "- Checking ramdisk status"
if [ -e ramdisk.cpio ]; then
  if ! ./magiskboot cpio ramdisk.cpio test; then
    abort "! Failed to test ramdisk patch status"
  fi
  STATUS=$?
  SKIP_BACKUP=""
else
  # Stock A only legacy SAR, or some Android 13 GKIs
  STATUS=0
  SKIP_BACKUP="#"
fi
case $((STATUS & 3)) in
  0 )  # Stock boot
    ui_print "- Stock boot image detected"
    SHA1=$(./magiskboot sha1 "$BOOTIMAGE" 2>/dev/null)
    cp -af ramdisk.cpio ramdisk.cpio.orig 2>/dev/null
    ;;
  1 )  # Magisk patched
    ui_print "- Magisk patched boot image detected"
    ./magiskboot cpio ramdisk.cpio \
    "extract .backup/.magisk config.orig" \
    "restore"
    cp -af ramdisk.cpio ramdisk.cpio.orig
    rm -f stock_boot.img
    ;;
  2 )  # Unsupported
    ui_print "! Boot image patched by unsupported programs"
    abort "! Please restore back to stock boot image"
    ;;
esac

# Workaround custom legacy Sony /init -> /(s)bin/init_sony : /init.real setup
INIT=init
if [ $((STATUS & 4)) -ne 0 ]; then
  INIT=init.real
fi

if [ -f config.orig ]; then
  # Read existing configs
  chmod 0644 config.orig
  SHA1=$(grep_prop SHA1 config.orig)
  if ! $BOOTMODE; then
    # Do not inherit config if not in recovery
    PREINITDEVICE=$(grep_prop PREINITDEVICE config.orig)
  fi
  rm config.orig
fi

##################
# Ramdisk Patches
##################

ui_print "- Patching ramdisk"

# Compress to save precious ramdisk space
SKIP32="#"
SKIP64="#"
if [ -f magisk64 ]; then
  PREINITDEVICE=metadata
  if ! ./magiskboot compress=xz magisk64 magisk64.xz; then
    abort "! Failed to compress magisk64 binary"
  fi
  unset SKIP64
fi
if [ -f magisk32 ]; then
  PREINITDEVICE=metadata
  if ! ./magiskboot compress=xz magisk32 magisk32.xz; then
    abort "! Failed to compress magisk32 binary"
  fi
  unset SKIP32
fi
if ! ./magiskboot compress=xz stub.apk stub.xz; then
  abort "! Failed to compress stub.apk binary"
fi

echo "KEEPVERITY=$KEEPVERITY" > config
echo "KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT" >> config
echo "RECOVERYMODE=$RECOVERYMODE" >> config
if [ -n "$PREINITDEVICE" ]; then
  ui_print "- Pre-init storage partition: $PREINITDEVICE"
  echo "PREINITDEVICE=$PREINITDEVICE" >> config
fi
[ -n "$SHA1" ] && echo "SHA1=$SHA1" >> config

if ! ./magiskboot cpio ramdisk.cpio \
"add 0750 $INIT magiskinit" \
"mkdir 0750 overlay.d" \
"mkdir 0750 overlay.d/sbin" \
"$SKIP32 add 0644 overlay.d/sbin/magisk32.xz magisk32.xz" \
"$SKIP64 add 0644 overlay.d/sbin/magisk64.xz magisk64.xz" \
"add 0644 overlay.d/sbin/stub.xz stub.xz" \
"patch" \
"$SKIP_BACKUP backup ramdisk.cpio.orig" \
"mkdir 000 .backup" \
"add 000 .backup/.magisk config"; then
  abort "! Failed to patch ramdisk"
fi

rm -f ramdisk.cpio.orig config magisk*.xz stub.xz

#################
# Binary Patches
#################

for dt in dtb kernel_dtb extra; do
  if [ -f "$dt" ]; then
    if ! ./magiskboot dtb "$dt" test; then
      ui_print "! Boot image $dt was patched by old (unsupported) Magisk"
      abort "! Please try again with *unpatched* boot image"
    fi
    if ! ./magiskboot dtb "$dt" patch; then
      abort "! Failed to patch $dt in boot image"
    fi
  fi
done

if [ -f kernel ]; then
  PATCHEDKERNEL=false
  # Remove Samsung RKP
  if ! ./magiskboot hexpatch kernel \
  49010054011440B93FA00F71E9000054010840B93FA00F7189000054001840B91FA00F7188010054 \
  A1020054011440B93FA00F7140020054010840B93FA00F71E0010054001840B91FA00F7181010054; then
    abort "! Failed to remove Samsung RKP from kernel"
  fi
  PATCHEDKERNEL=true

  # Remove Samsung defex
  # Before: [mov w2, #-221]   (-__NR_execve)
  # After:  [mov w2, #-32768]
  if ! ./magiskboot hexpatch kernel 821B8012 E2FF8F12; then
    abort "! Failed to remove Samsung defex from kernel"
  fi
  PATCHEDKERNEL=true

  # Force kernel to load rootfs for legacy SAR devices
  # skip_initramfs -> want_initramfs
  if $LEGACYSAR && ! ./magiskboot hexpatch kernel \
  736B69705F696E697472616D667300 \
  77616E745F696E697472616D667300; then
    abort "! Failed to force kernel to load rootfs for legacy SAR devices"
  fi
  PATCHEDKERNEL=true

  # If the kernel doesn't need to be patched at all,
  # keep raw kernel to avoid bootloops on some weird devices
  if ! $PATCHEDKERNEL; then
    rm -f kernel
  fi
fi

#################
# Repack & Flash
#################

ui_print "- Repacking boot image"

if ! ./magiskboot repack "$BOOTIMAGE
