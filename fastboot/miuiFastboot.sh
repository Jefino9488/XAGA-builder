#!/bin/bash

set -e
set -u
set -o pipefail

url="$1"
github_workspace="$2"
device="$3"

RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
color_red='\033[1;31m'
color_yellow='\033[1;33m'
color_blue='\033[1;34m'
color_green='\033[1;32m'

# Download package
echo -e "${BLUE}- Downloading package"
aria2c -x16 -j"$(nproc)" -U "Mozilla/5.0" -d "${github_workspace}" -o "recovery_rom.zip" "${url}"
echo -e "${GREEN}- Downloaded recovery rom"

# Set permissions and create directories
sudo chmod -R +rwx "${github_workspace}/tools"
mkdir -p "${github_workspace}/${device}"
mkdir -p "${github_workspace}/super_maker/config"
mkdir -p "${github_workspace}/zip"

# Extract payload.bin
echo -e "${YELLOW}- extracting payload.bin"
recovery_zip="recovery_rom.zip"
7z x "${github_workspace}/${recovery_zip}" -o"${github_workspace}/${device}" payload.bin || true
rm -rf "${github_workspace:?}/${recovery_zip}"
echo -e "${BLUE}- extracted payload.bin"

# Extract images
echo -e "${YELLOW}- extracting images"
mkdir -p "${github_workspace}/${device}/images"
"${github_workspace}/tools/payload-dumper-go" -o "${github_workspace}/${device}/images" "${GITHUB_WORKSPACE}/${DEVICE}/payload.bin" >/dev/null
sudo rm -rf "${github_workspace}/${device}/payload.bin"
echo -e "${BLUE}- extracted images"

# Move image files to super_maker directory
for img in vendor product system system_ext odm_dlkm odm mi_ext vendor_dlkm; do
    mv -t "${github_workspace}/super_maker" "${github_workspace}/${device}/images/$img.img" || exit
    eval "${img}_size=\$(du -b \"${github_workspace}/super_maker/$img.img\" | awk '{print \$1}')"
    echo -e "${BLUE}- moved img"
done

# Calculate total size of all images
echo -e "${YELLOW}- calculating total size of all images"
super_size=9126805504
total_size=$((system_size + system_ext_size + product_size + vendor_size + odm_size + odm_dlkm_size + vendor_dlkm_size))
echo -e "${BLUE}- size of all images"
echo -e "system: $system_size"
echo -e "system_ext: $system_ext_size"
echo -e "product: $product_size"
echo -e "vendor: $vendor_size"
echo -e "odm: $odm_size"
echo -e "odm_dlkm: $odm_dlkm_size"
echo -e "vendor_dlkm: $vendor_dlkm_size"
echo -e "total size: $total_size"

# Create super image
echo -e "${YELLOW}- creating super image"
"${github_workspace}/tools/lpmake" --metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 3 \
    --device super:"${super_size}" --group main_a:"${total_size}" --group main_b:"${total_size}" \
    --partition system_a:readonly:"${system_size}":main_a --image system_a=./super_maker/system.img \
    --partition system_b:readonly:0:main_b \
    --partition system_ext_a:readonly:"${system_ext_size}":main_a --image system_ext_a=./super_maker/system_ext.img \
    --partition system_ext_b:readonly:0:main_b \
    --partition product_a:readonly:"${product_size}":main_a --image product_a=./super_maker/product.img \
    --partition product_b:readonly:0:main_b \
    --partition vendor_a:readonly:"${vendor_size}":main_a --image vendor_a=./super_maker/vendor.img \
    --partition vendor_b:readonly:0:main_b \
    --partition odm_dlkm_a:readonly:"${odm_dlkm_size}":main_a --image odm_dlkm_a=./super_maker/odm_dlkm.img \
    --partition odm_dlkm_b:readonly:0:main_b \
    --partition odm_a:readonly:"${odm_size}":main_a --image odm_a=./super_maker/odm.img \
    --partition odm_b:readonly:0:main_b \
    --partition vendor_dlkm_a:readonly:"${vendor_dlkm_size}":main_a --image vendor_dlkm_a=./super_maker/vendor_dlkm.img \
    --partition vendor_dlkm_b:readonly:0:main_b \
    --virtual-ab --sparse --output "${github_workspace}/super_maker/super.img" || exit
echo -e "${BLUE}- created super image"

# Move super image to the images directory
echo -e "${YELLOW}- moving super image"
mv -t "${github_workspace}/${device}/images" "${github_workspace}/super_maker/super.img" || exit
echo -e "${BLUE}- moved super image"

# Create device working directory
echo -e "${YELLOW}- ${device} fastboot working directory"
mkdir -p "${github_workspace}/${device}/boot"
mkdir -p "${github_workspace}/${device}/vendor_boot"
mkdir -p "${github_workspace}/zip"

# Patch boot image
echo -e "${YELLOW}- patching boot image"
cp "${github_workspace}/${device}/images/boot.img" "${github_workspace}/${DEVICE}/boot/"
chmod +x "${MAGISK_PATCH}"
${MAGISK_PATCH} "${github_workspace}/${device}/boot/boot.img"
if [ $? -ne 0 ]; then
    echo -e "${RED}- failed to patch boot image"
    exit 1
fi
echo -e "${BLUE}- patched boot image"

mv "${github_workspace}/magisk/new-boot.img" "${github_workspace}/${device}/boot/magisk_boot.img"

mv "${github_workspace}/${device}/images/boot.img" "${github_workspace}/${device}/boot/"

mv "${github_workspace}/${device}/images/vendor_boot.img" "${github_workspace}/${device}/vendor_boot/"

cp "${github_workspace}/tools/flasher.exe" "${github_workspace}/${device}/"

if [ -f "${github_workspace}/tools/preloader_ari.bin" ]; then
    cp "${github_workspace}/tools/preloader_ari.bin" "${github_workspace}/${device}/images/"
    echo -e "${color_green}preloader_ari.bin copied successfully"
else
    echo -e "${color_red}Failed to copy preloader_ari.bin"
fi

cd "${github_workspace}" || exit

# Zip fastboot files
echo -e "${YELLOW}- ziping fastboot files"
zip -r "${github_workspace}/zip/${device}_fastboot.zip" "${device}" || true
echo -e "${color_green}- ${device}_fastboot.zip created successfully"