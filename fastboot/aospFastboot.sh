#!/bin/bash -l

set -e

URL="$1"
GITHUB_WORKSPACE="$2"
DEVICE="$3"
KEY="$4"

MAGISK_PATCH="${GITHUB_WORKSPACE}/magisk/boot_patch.sh"
UPLOAD="${GITHUB_WORKSPACE}/tools/upload.sh"
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'

trap 'rm -rf "${TMPDIR}"' EXIT
TMPDIR=$(mktemp -d)

# Download recovery rom
echo -e "${BLUE}- Starting downloading recovery rom"
aria2c -x16 -j"$(nproc)" -U "Mozilla/5.0" -d "${GITHUB_WORKSPACE}" -o "recovery_rom.zip" "${URL}"
echo -e "${GREEN}- Downloaded recovery rom"

# Set permissions and create directories
sudo chmod -R +rwx "${GITHUB_WORKSPACE}/tools"
mkdir -p "${GITHUB_WORKSPACE}/${DEVICE}"
mkdir -p "${GITHUB_WORKSPACE}/super_maker/config"
mkdir -p "${GITHUB_WORKSPACE}/zip"

# Extract payload.bin
echo -e "${YELLOW}- extracting payload.bin"
RECOVERY_ZIP="recovery_rom.zip"
7z x "${GITHUB_WORKSPACE}/${RECOVERY_ZIP}" -o"${GITHUB_WORKSPACE}/${DEVICE}" payload.bin || true
rm -rf "${GITHUB_WORKSPACE:?}/${RECOVERY_ZIP}"
echo -e "${BLUE}- extracted payload.bin"

# Extract images
echo -e "${YELLOW}- extracting images"
mkdir -p "${GITHUB_WORKSPACE}/${DEVICE}/images"
"${GITHUB_WORKSPACE}/tools/payload-dumper-go" -o "${GITHUB_WORKSPACE}/${DEVICE}/images" "${GITHUB_WORKSPACE}/${DEVICE}/payload.bin" >/dev/null
sudo rm -rf "${GITHUB_WORKSPACE}/${DEVICE}/payload.bin"
echo -e "${BLUE}- extracted images"

# Move images to the super_maker directory
echo -e "${YELLOW}- moving images to super_maker"
for IMAGE in vendor product system system_ext odm_dlkm odm vendor_dlkm; do
    mv -t "${GITHUB_WORKSPACE}/super_maker" "${GITHUB_WORKSPACE}/${DEVICE}/images/$IMAGE.img" || exit
    eval "${IMAGE}_size=\$(du -b \"${GITHUB_WORKSPACE}/super_maker/$IMAGE.img\" | awk '{print \$1}')"
    echo -e "${BLUE}- moved $IMAGE"
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
"${GITHUB_WORKSPACE}/tools/lpmake" --metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 3 \
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
    --virtual-ab --sparse --output "${GITHUB_WORKSPACE}/super_maker/super.img" || exit
echo -e "${BLUE}- created super image"

# Move super image to the images directory
echo -e "${YELLOW}- moving super image"
mv -t "${GITHUB_WORKSPACE}/${DEVICE}/images" "${GITHUB_WORKSPACE}/super_maker/super.img" || exit
echo -e "${BLUE}- moved super image"

# Create device working directory
echo -e "${YELLOW}- ${DEVICE} fastboot working directory"
mkdir -p "${GITHUB_WORKSPACE}/${DEVICE}/boot"
mkdir -p "${GITHUB_WORKSPACE}/${DEVICE}/vendor_boot"
mkdir -p "${GITHUB_WORKSPACE}/zip"

# Patch boot image
echo -e "${YELLOW}- patching boot image"
cp "${GITHUB_WORKSPACE}/${DEVICE}/images/boot.img" "${GITHUB_WORKSPACE}/${DEVICE}/boot/"
chmod +x "${MAGISK_PATCH}"
${MAGISK_PATCH} "${GITHUB_WORKSPACE}/${DEVICE}/boot/boot.img"
if [ $? -ne 0 ]; then
    echo -e "${RED}- failed to patch boot image"
    exit 1
fi
echo -e "${BLUE}- patched boot image"

mv "${GITHUB_WORKSPACE}/magisk/new-boot.img" "${GITHUB_WORKSPACE}/${DEVICE}/boot/magisk_boot.img"

mv "${GITHUB_WORKSPACE}/${DEVICE}/images/boot.img" "${GITHUB_WORKSPACE}/${DEVICE}/boot/"

mv "${GITHUB_WORKSPACE}/${DEVICE}/images/vendor_boot.img" "${GITHUB_WORKSPACE}/${DEVICE}/vendor_boot/"

mv "${GITHUB_WORKSPACE}/tools/flasher.exe" "${GITHUB_WORKSPACE}/${DEVICE}/"

cd "${GITHUB_WORKSPACE}" || exit
echo -e "${BLUE}- created ${DEVICE} working directory"

# Zip fastboot files
echo -e "${YELLOW}- ziping fastboot files"
zip -r "${GITHUB_WORKSPACE}/zip/${DEVICE}_fastboot.zip" "${DEVICE}" || true
echo -e "${GREEN}- ${DEVICE}_fastboot.zip created successfully"
