#!/bin/bash

set -e
set -u
set -o pipefail

url="$1"
github_workspace="$2"
device="$3"
key="$4"

color_red='\033[1;31m'
color_yellow='\033[1;33m'
color_blue='\033[1;34m'
color_green='\033[1;32m'

# Download package
echo -e "${color_red}- Downloading package"
aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "${github_workspace}" -o "recovery_rom.zip" "${url}"
echo -e "${color_red}- Downloaded recovery rom"

# Set permissions and create directories
sudo chmod -R 777 "${github_workspace}/tools"
mkdir -p "${github_workspace}/${device}"
mkdir -p "${github_workspace}/super_maker/config"
mkdir -p "${github_workspace}/zip"

# Extract recovery zip
recovery_zip="recovery_rom.zip"
7z x "${github_workspace}/${recovery_zip}" -o"${github_workspace}/${device}" payload.bin
rm -rf "${github_workspace}/${recovery_zip}"

# Extract images from payload.bin
mkdir -p "${github_workspace}/${device}/images"
"${github_workspace}/tools/payload-dumper-go" -o "${github_workspace}/${device}/images" "${github_workspace}/${device}/payload.bin" >/dev/null
sudo rm -rf "${github_workspace}/${device}/payload.bin"

# Move image files to super_maker directory
for img in vendor product system system_ext odm_dlkm odm mi_ext vendor_dlkm; do
    mv "${github_workspace}/${device}/images/${img}.img" "${github_workspace}/super_maker/"

    # Define the path to the directory containing the image files
    eval "${img}_size=$(du -sb "${github_workspace}/super_maker/${img}.img" | awk {'print $1'})"
done

# Create super image
"${github_workspace}/tools/lpmake" --metadata-size 65536 --super-name super --block-size 4096 \
--partition mi_ext_a:readonly:"${mi_ext_size}":dynamic_partitions_a --image mi_ext_a="${github_workspace}/super_maker/mi_ext.img" \
--partition mi_ext_b:readonly:0:dynamic_partitions_b \
--partition odm_a:readonly:"${odm_size}":dynamic_partitions_a --image odm_a="${github_workspace}/super_maker/odm.img" \
--partition odm_b:readonly:0:dynamic_partitions_b \
--partition product_a:readonly:"${product_size}":dynamic_partitions_a --image product_a="${github_workspace}/super_maker/product.img" \
--partition product_b:readonly:0:dynamic_partitions_b \
--partition system_a:readonly:"${system_size}":dynamic_partitions_a --image system_a="${github_workspace}/super_maker/system.img" \
--partition system_b:readonly:0:dynamic_partitions_b \
--partition system_ext_a:readonly:"${system_ext_size}":dynamic_partitions_a --image system_ext_a="${github_workspace}/super_maker/system_ext.img" \
--partition system_ext_b:readonly:0:dynamic_partitions_b \
--partition vendor_a:readonly:"${vendor_size}":dynamic_partitions_a --image vendor_a="${github_workspace}/super_maker/vendor.img" \
--partition vendor_b:readonly:0:dynamic_partitions_b \
--partition vendor_dlkm_a:readonly:"${vendor_dlkm_size}":dynamic_partitions_a --image vendor_dlkm_a="${github_workspace}/super_maker/vendor_dlkm.img" \
--partition vendor_dlkm_b:readonly:0:dynamic_partitions_b \
--device super:9126805504 --metadata-slots 3 --group dynamic_partitions_a:9126805504 \
--group dynamic_partitions_b:9126805504 --virtual-ab --output "${github_workspace}/super_maker/super.img"

# Move super.img to images directory
mv "${github_workspace}/super_maker/super.img" "${github_workspace}/${device}/images/"
echo "moved super.img"

# Create boot and vendor_boot directories
mkdir -p "${github_workspace}/${device}/boot"
mkdir -p "${github_workspace}/${device}/vendor_boot"
mkdir -p "${github_workspace}/zip"

# Patch boot image
magisk_patch="${github_workspace}/magisk/boot_patch.sh"

echo -e "${color_yellow}- patching boot image"
cp "${github_workspace}/${device}/images/boot.img" "${github_workspace}/${device}/boot/"

chmod +x "${github_workspace}/magisk"

if "${magisk_patch}" "${github_workspace}/${device}/boot/boot.img"; then
    echo -e "${color_blue}- patched boot image"
else
    echo -e "${color_red}- failed to patch boot image"
    exit 1
fi

# Move patched boot image to boot directory
mv "${github_workspace}/magisk/new-boot.img" "${github_workspace}/${device}/boot/magisk_boot.img"

# Move original boot and vendor_boot images to their respective directories
mv "${github_workspace}/${device}/images/boot.img" "${github_workspace}/${device}/boot/"
mv "${github_workspace}/${device}/images/vendor_boot.img" "${github_workspace}/${device}/vendor_boot/"

# Copy flasher.exe to device directory
cp "${github_workspace}/tools/flasher.exe" "${github_workspace}/${device}/"

# Copy preloader_ari.bin to images directory
if [ -f "${github_workspace}/tools/preloader_ari.bin" ]; then
    cp "${github_workspace}/tools/preloader_ari.bin" "${github_workspace}/${device}/images/"
    echo -e "${color_green}preloader_ari.bin copied successfully"
else
    echo -e "${color_red}Failed to copy preloader_ari.bin"
fi

# Create zip file
cd "${github_workspace}" || exit
zip -r "${github_workspace}/zip/${device}_fastboot.zip" "${device}"

echo -e "${color_green}- ${device}_fastboot.zip created successfully"