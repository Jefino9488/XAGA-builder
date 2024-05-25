#!/bin/bash -l

set -e

URL="$1"
GITHUB_WORKSPACE="$2"
DEVICE="$3"
KEY="$4"
FIRMWARE_URL="$5"  # New input for firmware URL

MAGISK_PATCH="${GITHUB_WORKSPACE}/magisk/boot_patch.sh"
UPLOAD="${GITHUB_WORKSPACE}/tools/upload.sh"
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'

trap 'rm -rf "${TMPDIR}"' EXIT
TMPDIR=$(mktemp -d)

download_recovery_rom() {
    echo -e "${BLUE}- Starting downloading recovery rom"
    aria2c -x16 -j"$(nproc)" -U "Mozilla/5.0" -d "${GITHUB_WORKSPACE}" -o "recovery_rom.zip" "${URL}"
    echo -e "${GREEN}- Downloaded recovery rom"
}

set_permissions_and_create_dirs() {
    sudo chmod -R +rwx "${GITHUB_WORKSPACE}/tools"
    mkdir -p "${GITHUB_WORKSPACE}/${DEVICE}"
    mkdir -p "${GITHUB_WORKSPACE}/super_maker/config"
    mkdir -p "${GITHUB_WORKSPACE}/zip"
}

extract_payload_bin() {
    echo -e "${YELLOW}- Extracting payload.bin"
    RECOVERY_ZIP="recovery_rom.zip"
    7z x "${GITHUB_WORKSPACE}/${RECOVERY_ZIP}" -o"${GITHUB_WORKSPACE}/${DEVICE}" payload.bin || true
    rm -rf "${GITHUB_WORKSPACE:?}/${RECOVERY_ZIP}"
    echo -e "${BLUE}- Extracted payload.bin"
}

extract_images() {
    echo -e "${YELLOW}- Extracting images"
    mkdir -p "${GITHUB_WORKSPACE}/${DEVICE}/images"
    "${GITHUB_WORKSPACE}/tools/payload-dumper-go" -o "${GITHUB_WORKSPACE}/${DEVICE}/images" "${GITHUB_WORKSPACE}/${DEVICE}/payload.bin" >/dev/null
    sudo rm -rf "${GITHUB_WORKSPACE}/${DEVICE}/payload.bin"
    echo -e "${BLUE}- Extracted images"
}

move_images_and_calculate_sizes() {
    echo -e "${YELLOW}- Moving images to super_maker and calculating sizes"
    local IMAGE
    for IMAGE in vendor product system system_ext odm_dlkm odm vendor_dlkm; do
        mv -t "${GITHUB_WORKSPACE}/super_maker" "${GITHUB_WORKSPACE}/${DEVICE}/images/$IMAGE.img" || exit
        eval "${IMAGE}_size=\$(du -b \"${GITHUB_WORKSPACE}/super_maker/$IMAGE.img\" | awk '{print \$1}')"
        echo -e "${BLUE}- Moved $IMAGE"
    done

    # Calculate total size of all images
    echo -e "${YELLOW}- Calculating total size of all images"
    super_size=9126805504
    total_size=$((system_size + system_ext_size + product_size + vendor_size + odm_size + odm_dlkm_size + vendor_dlkm_size))
    echo -e "${BLUE}- Size of all images"
    echo -e "system: $system_size"
    echo -e "system_ext: $system_ext_size"
    echo -e "product: $product_size"
    echo -e "vendor: $vendor_size"
    echo -e "odm: $odm_size"
    echo -e "odm_dlkm: $odm_dlkm_size"
    echo -e "vendor_dlkm: $vendor_dlkm_size"
    echo -e "total size: $total_size"
}

create_super_image() {
    echo -e "${YELLOW}- Creating super image"
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
    echo -e "${BLUE}- Created super image"
}

move_super_image() {
    echo -e "${YELLOW}- Moving super image"
    mv -t "${GITHUB_WORKSPACE}/${DEVICE}/images" "${GITHUB_WORKSPACE}/super_maker/super.img" || exit
    echo -e "${BLUE}- Moved super image"
}

prepare_device_directory() {
    echo -e "${YELLOW}- Preparing ${DEVICE} fastboot working directory"
    mkdir -p "${GITHUB_WORKSPACE}/${DEVICE}/boot"
    mkdir -p "${GITHUB_WORKSPACE}/${DEVICE}/vendor_boot"
    mkdir -p "${GITHUB_WORKSPACE}/zip"
}

patch_boot_image() {
    echo -e "${YELLOW}- Patching boot image"
    cp "${GITHUB_WORKSPACE}/${DEVICE}/images/boot.img" "${GITHUB_WORKSPACE}/${DEVICE}/boot/"
    chmod +x "${MAGISK_PATCH}"
    ${MAGISK_PATCH} "${GITHUB_WORKSPACE}/${DEVICE}/boot/boot.img"
    if [ $? -ne 0 ]; then
        echo -e "${RED}- Failed to patch boot image"
        exit 1
    fi
    echo -e "${BLUE}- Patched boot image"
}

download_and_extract_firmware() {
    if [ -n "${FIRMWARE_URL}" ]; then
        echo -e "${BLUE}- Starting downloading firmware"
        git clone --recurse-submodules https://github.com/AndroidDumps/Firmware_extractor.git "${TMPDIR}/Firmware_extractor"
        cd "${TMPDIR}/Firmware_extractor"
        wget "${FIRMWARE_URL}" -O firmware.zip
        ./extractor.sh firmware.zip
        echo -e "${GREEN}- Downloaded and extracted firmware"

        # Move extracted firmware images to the images folder
        mv -t "${GITHUB_WORKSPACE}/${DEVICE}/images" "${TMPDIR}/Firmware_extractor/out"/* || exit
        echo -e "${BLUE}- Moved extracted firmware images"
        cd "${GITHUB_WORKSPACE}"
    fi
}

final_steps() {
    mv "${GITHUB_WORKSPACE}/magisk/new-boot.img" "${GITHUB_WORKSPACE}/${DEVICE}/boot/magisk_boot.img"
    mv "${GITHUB_WORKSPACE}/${DEVICE}/images/boot.img" "${GITHUB_WORKSPACE}/${DEVICE}/boot/"
    mv "${GITHUB_WORKSPACE}/${DEVICE}/images/vendor_boot.img" "${GITHUB_WORKSPACE}/${DEVICE}/vendor_boot/"
    mv "${GITHUB_WORKSPACE}/tools/flasher.exe" "${GITHUB_WORKSPACE}/${DEVICE}/"

    cd "${GITHUB_WORKSPACE}" || exit
    echo -e "${BLUE}- Created ${DEVICE} working directory"

    echo -e "${YELLOW}- Zipping fastboot files"
    zip -r "${GITHUB_WORKSPACE}/zip/${DEVICE}_fastboot.zip" "${DEVICE}" || true
    echo -e "${GREEN}- ${DEVICE}_fastboot.zip created successfully"
}

# Main Execution
download_recovery_rom
set_permissions_and_create_dirs
extract_payload_bin
extract_images
download_and_extract_firmware  # New step to handle firmware extraction
move_images_and_calculate_sizes
create_super_image
move_super_image
prepare_device_directory
patch_boot_image
final_steps
