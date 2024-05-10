#!/bin/bash

URL="$1"
GITHUB_WORKSPACE="$2"
device="$3"

RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'

erofs_extract="$GITHUB_WORKSPACE"/tools/extract.erofs
erofs_mkfs="$GITHUB_WORKSPACE"/tools/mkfs.erofs
payload_extract="$GITHUB_WORKSPACE"/tools/payload-dumper-go

# Download package
download_package() {
  echo -e "${BLUE}- Downloading package${NO_COLOR}"
  if ! aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "$GITHUB_WORKSPACE" -o "hyper_rom.zip" "${URL}"; then
    echo -e "${RED}- Failed to download package${NO_COLOR}"
    exit 1
  fi
  echo -e "${GREEN}- Downloaded recovery rom${NO_COLOR}"
}

# Extract payload.bin
extract_payload() {
  echo -e "${BLUE}- Extracting payload.bin${NO_COLOR}"
  if ! $payload_extract -o "$GITHUB_WORKSPACE"/${device}/images "$GITHUB_WORKSPACE/${device}/payload.bin" >/dev/null; then
    echo -e "${RED}- Failed to extract payload.bin${NO_COLOR}"
    exit 1
  fi
  sudo rm -rf "$GITHUB_WORKSPACE/${device}/payload.bin"
}

# Extract images
extract_images() {
  for i in product system system_ext vendor; do
    echo -e "${YELLOW}- Extracting: $i${NO_COLOR}"
    if ! sudo $erofs_extract -s -i "$GITHUB_WORKSPACE"/${device}/images/$i.img -x; then
      echo -e "${RED}- Failed to extract $i${NO_COLOR}"
      exit 1
    fi
    rm -rf "$GITHUB_WORKSPACE"/${device}/images/$i.img
  done
}

# Delete unnecessary directories
delete_directories() {
  apps=("wps-lite" "MIUIWeather" "MIUICleanMaster")

  all_dirs=$(sudo find "$GITHUB_WORKSPACE"/${device}/images/product/data-app/ -type d)

  while IFS= read -r dir; do
    dir_name=$(basename "$dir")

    found=false

    for app in "${apps[@]}"; do
      if [[ "$app" == "$dir_name" ]]; then
        found=true
        break
      fi
    done
    # If the directory is not in the apps array, delete it
    if ! $found; then
      echo -e "${YELLOW}- Deleting directory: $dir${NO_COLOR}"
      sudo rm -rf "$dir"
    fi
  done <<< "$all_dirs"
}

# Debloat
debloat() {
  apps=("AutoRegistration"
    "Backup"
    "ConfigUpdater"
    "DownloadProviderUi"
    "GmsCore"
    "GoogleOneTimeInitializer"
    "GooglePlayServicesUpdater"
    "InCallUI"
    "MISettings"
    "MIShare"
    "MIUIAICR"
    "MIUIAod"
    "MIUIBarrageV2"
    "MIUICalendar"
    "MIUICloudBackup"
    "MIUIContactsT"
    "MIUIContentExtension"
    "MIUIGallery"
    "MIUIMirror"
    "MIUIPackageInstaller"
    "MIUIPersonalAssistantPhoneMIUI15"
    "MIUISecurityCenter"
    "MiuiCamera"
    "MiuiExtraPhoto"
    "MiuiHome"
    "MiuiMms"
    "RegService"
    "SettingsIntelligence")

  all_dirs=$(sudo find "$GITHUB_WORKSPACE"/${device}/images/product/priv-app/ -type d)

  while IFS= read -r dir; do
    dir_name=$(basename "$dir")

    found=false

    for app in "${apps[@]}"; do
      if [[ "$app" == "$dir_name" ]]; then
        found=true
        break
      fi
    done
    # If the directory is not in the apps array, delete it
    if ! $found; then
      echo -e "${YELLOW}- Deleting directory: $dir${NO_COLOR}"
      sudo rm -rf "$dir"
    fi
  done <<< "$all_dirs"
}

# Build super.img
build_super_img() {
  for partition in "${partitions[@]}"; do
    echo -e "${RED}- Build img: $partition${NO_COLOR}"
    if ! sudo python3 "$GITHUB_WORKSPACE"/tools/fspatch.py "$GITHUB_WORKSPACE"/${device}/images/$partition "$GITHUB_WORKSPACE"/${device}/images/config/"$partition"_fs_config; then
      echo -e "${RED}- Failed to build img: $partition${NO_COLOR}"
      exit 1
    fi
    if ! sudo python3 "$GITHUB_WORKSPACE"/tools/contextpatch.py "$GITHUB_WORKSPACE"/${device}/images/$partition "$GITHUB_WORKSPACE"/${device}/images/config/"$partition"_file_contexts; then
      echo -e "${RED}- Failed to build img: $partition${NO_COLOR}"
      exit 1
    fi
    if ! sudo $erofs_mkfs --quiet -zlz4hc,9 -T 1230768000 --mount-point /$partition --fs-config-file "$GITHUB_WORKSPACE"/${device}/images/config/"$partition"_fs_config --file-contexts "$GITHUB_WORKSPACE"/${device}/images/config/"$partition"_file_contexts "$GITHUB_WORKSPACE"/${device}/images/$partition.img; then
      echo -e "${RED}- Failed to build img: $partition${NO_COLOR}"
      exit 1
    fi
    eval "${partition}_size=$(du -sb "$GITHUB_WORKSPACE"/${device}/images/$partition.img | awk '{print $1}')"
    sudo rm -rf "$GITHUB_WORKSPACE"/${device}/images/$partition
  done
}

# Create super.img
create_super_img() {
  sudo "$GITHUB_WORKSPACE"/tools/lpmake --metadata-size 65536 --super-name super --block-size 4096 \
  --partition mi_ext_a:readonly:"$mi_ext_size":dynamic_partitions_a --image mi_ext_a="$GITHUB_WORKSPACE"/super_maker/mi_ext.img \
  --partition mi_ext_b:readonly:0:dynamic_partitions_b \
  --partition odm_a:readonly:"$odm_size":dynamic_partitions_a --image odm_a="$GITHUB_WORKSPACE"/super_maker/odm.img \
  --partition odm_b:readonly:0:dynamic_partitions_b \
  --partition product_a:readonly:"$product_size":dynamic_partitions_a --image product_a="$GITHUB_WORKSPACE"/super_maker/product.img \
  --partition product_b:readonly:0:dynamic_partitions_b \
  --partition system_a:readonly:"$system_size":dynamic_partitions_a --image system_a="$GITHUB_WORKSPACE"/super_maker/system.img \
  --partition system_b:readonly:0:dynamic_partitions_b \
  --partition system_ext_a:readonly:"$system_ext_size":dynamic_partitions_a --image system_ext_a="$GITHUB_WORKSPACE"/super_maker/system_ext.img \
  --partition system_ext_b:readonly:0:dynamic_partitions_b \
  --partition vendor_a:readonly:"$vendor_size":dynamic_partitions_a --image vendor_a="$GITHUB_WORKSPACE"/super_maker/vendor.img \
  --partition vendor_b:readonly:0:dynamic_partitions_b \
  --partition vendor_dlkm_a:readonly:"$vendor_dlkm_size":dynamic_partitions_a --image vendor_dlkm_a="$GITHUB_WORKSPACE"/super_maker/vendor_dlkm.img \
  --partition vendor_dlkm_b:readonly:0:dynamic_partitions_b \
  --device super:9126805504 --metadata-slots 3 --group dynamic_partitions_a:9126805504 \
  --group dynamic_partitions_b:9126805504 --virtual-ab --output "$GITHUB_WORKSPACE"/super_maker/super.img

  mv "$GITHUB_WORKSPACE/super_maker/super.img" "$GITHUB_WORKSPACE/${device}/images/"
  echo moved super
}

# Patch boot image
patch_boot_image() {
  cp "$GITHUB_WORKSPACE/${device}/images/boot.img" "$GITHUB_WORKSPACE/${device}/boot/"

  chmod +x "$GITHUB_WORKSPACE/magisk/boot_patch.sh"

  if ! "$GITHUB_WORKSPACE"/magisk/boot_patch.sh "$GITHUB_WORKSPACE/${device}/boot/boot.img" ; then
    echo -e "${RED}- Failed to patch boot image${NO_COLOR}"
    exit 1
  fi

  mv "$GITHUB_WORKSPACE/magisk/new-boot.img" "$GITHUB_WORKSPACE/${device}/boot/magisk_boot.img"
}

# Create zip file
create_zip() {
  zip -r "$GITHUB_WORKSPACE/zip/${device}_fastboot.zip" "${device}"

  echo "Created ${device}_fastboot.zip"
}

# Main
set -e

mkdir -p "$GITHUB_WORKSPACE/tools"
mkdir -p "$GITHUB_WORKSPACE/${device}"
mkdir -p "$GITHUB_WORKSPACE/super_maker/config"
mkdir -p "$GITHUB_WORKSPACE/zip"

download_package "$URL"

sudo chmod -R 777 "$GITHUB_WORKSPACE/tools"

RECOVERY_ZIP="hyper_rom.zip"
7z x "$GITHUB_WORKSPACE/$RECOVERY_ZIP" -o"$GITHUB_WORKSPACE/${device}" payload.bin
rm -rf "${GITHUB_WORKSPACE:?}/$RECOVERY_ZIP"

mkdir -p "$GITHUB_WORKSPACE/${device}/images"
extract_payload

extract_images

delete_directories

debloat

build_super_img

create_super_img

patch_boot_image

create_zip
