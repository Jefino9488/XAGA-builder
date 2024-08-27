sudo apt-get remove -y firefox zstd
sudo apt-get install python3 aria2

URL="$1"
DEVICE="$2"
WORKSPACE="$3"

RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'

MAGISK_PATCH="${WORKSPACE}/magisk/boot_patch.sh"
# Set Permissions and create directories
sudo chmod -R +rwx "${WORKSPACE}/tools"

# Grant execution permissions to the tools
sudo chmod +x "${WORKSPACE}/tools/payload-dumper-go"
sudo chmod +x "${WORKSPACE}/tools/extract.erofs"
sudo chmod +x "${WORKSPACE}/tools/fspatch.py"
sudo chmod +x "${WORKSPACE}/tools/contextpatch.py"
sudo chmod +x "${WORKSPACE}/tools/mkfs.erofs"
# Download package
echo -e "${BLUE}- Downloading package"
aria2c -x16 -j"$(nproc)" -U "Mozilla/5.0" -d "${WORKSPACE}" -o "recovery_rom.zip" "${URL}"

# Extract payload.bin
echo -e "${YELLOW}- extracting payload.bin"
recovery_zip="recovery_rom.zip"
7z x "${WORKSPACE}/${recovery_zip}" -o"${WORKSPACE}/${DEVICE}" payload.bin || true
rm -rf "${WORKSPACE:?}/${recovery_zip}"
echo -e "${BLUE}- extracted payload.bin"

# Extract images
echo -e "${YELLOW}- extracting images"
mkdir -p "${WORKSPACE}/${DEVICE}/images"
"${WORKSPACE}/tools/payload-dumper-go" -o "${WORKSPACE}/${DEVICE}/images" "${WORKSPACE}/${DEVICE}/payload.bin" >/dev/null
sudo rm -rf "${WORKSPACE}/${DEVICE}/payload.bin"
echo -e "${BLUE}- extracted images"

echo -e "${YELLOW}- decompressing images"
for i in product system system_ext; do
  echo -e "${YELLOW}- Decomposing image: $i"
  sudo "${WORKSPACE}/tools/extract.erofs" -s -i "${WORKSPACE}/${DEVICE}/images/$i.img" -x -o "${WORKSPACE}/${DEVICE}/images/"
  rm -rf "${WORKSPACE}/${DEVICE}/images/$i.img"
  echo -e "${BLUE}- decompressed $i"
done

# repack images
echo -e "${YELLOW}- repacking images"
partitions=("product" "system" "system_ext")
for partition in "${partitions[@]}"; do
  echo -e "${Red}- generating: $partition"
  sudo python3 "$WORKSPACE"/tools/fspatch.py "$WORKSPACE"/"${DEVICE}"/images/$partition "$WORKSPACE"/"${DEVICE}"/images/config/"$partition"_fs_config
  sudo python3 "$WORKSPACE"/tools/contextpatch.py "$WORKSPACE"/${DEVICE}/images/$partition "$WORKSPACE"/"${DEVICE}"/images/config/"$partition"_file_contexts
  sudo "${WORKSPACE}/tools/mkfs.erofs" --quiet -zlz4hc,9 -T 1230768000 --mount-point /"$partition" --fs-config-file "$WORKSPACE"/"${DEVICE}"/images/config/"$partition"_fs_config --file-contexts "$WORKSPACE"/"${DEVICE}"/images/config/"$partition"_file_contexts "$WORKSPACE"/"${DEVICE}"/images/$partition.img "$WORKSPACE"/"${DEVICE}"/images/$partition
  sudo rm -rf "$WORKSPACE"/"${DEVICE}"/images/$partition
done
echo -e "${Green}- All partitions repacked"

move_images_and_calculate_sizes() {
    echo -e "${YELLOW}- Moving images to super_maker and calculating sizes"
    local IMAGE
    for IMAGE in vendor product system system_ext odm_dlkm odm vendor_dlkm; do
        mv -t "${WORKSPACE}/super_maker" "${WORKSPACE}/${DEVICE}/images/$IMAGE.img" || exit
        eval "${IMAGE}_size=\$(du -b \"${WORKSPACE}/super_maker/$IMAGE.img\" | awk '{print \$1}')"
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
    "${WORKSPACE}/tools/lpmake" --metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 3 \
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
        --virtual-ab --sparse --output "${WORKSPACE}/super_maker/super.img" || exit
    echo -e "${BLUE}- Created super image"
}

move_super_image() {
    echo -e "${YELLOW}- Moving super image"
    mv -t "${WORKSPACE}/${DEVICE}/images" "${WORKSPACE}/super_maker/super.img" || exit
    sudo rm -rf "${WORKSPACE}/super_maker"
    echo -e "${BLUE}- Moved super image"
}

prepare_device_directory() {
    echo -e "${YELLOW}- Downloading and preparing ${DEVICE} fastboot working directory"

    LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/Jefino9488/Fastboot-Flasher/releases/latest | grep "browser_download_url.*zip" | cut -d '"' -f 4)
    aria2c -x16 -j"$(nproc)" -U "Mozilla/5.0" -o "fastboot_flasher_latest.zip" "${LATEST_RELEASE_URL}"

    unzip -q "fastboot_flasher_latest.zip" -d "${WORKSPACE}/zip"

    rm "fastboot_flasher_latest.zip"

    echo -e "${BLUE}- Downloaded and prepared ${DEVICE} fastboot working directory"
}

patch_boot_image() {
    echo -e "${YELLOW}- Patching boot image"
    chmod +x "${MAGISK_PATCH}"
    ${MAGISK_PATCH} "${WORKSPACE}/${DEVICE}/images/boot.img"
    if [ $? -ne 0 ]; then
        echo -e "${RED}- Failed to patch boot image"
        exit 1
    fi
    echo -e "${BLUE}- Patched boot image"
}

final_steps() {
    mv "${WORKSPACE}/magisk/new-boot.img" "${WORKSPACE}/${DEVICE}/images/magisk_boot.img"

    if [ -d "${WORKSPACE}/new_firmware" ]; then
        mv -t "${WORKSPACE}/${DEVICE}/images" "${WORKSPACE}/new_firmware"/* || exit
        sudo rm -rf "${WORKSPACE}/new_firmware"
    fi

    mkdir -p "${WORKSPACE}/zip/images"

    cp "${WORKSPACE}/${DEVICE}/images"/* "${WORKSPACE}/zip/images/"

    cd "${WORKSPACE}/zip" || exit

    echo -e "${YELLOW}- Zipping fastboot files"
    zip -r "${WORKSPACE}/zip/${DEVICE}_fastboot.zip" . || true
    echo -e "${GREEN}- ${DEVICE}_fastboot.zip created successfully"
    rm -rf "${WORKSPACE}/zip/images"

    echo -e "${GREEN}- All done!"
}
echo -e "${YELLOW}- listing all content"
ls -alh "${WORKSPACE}/${DEVICE}/images"
ls -alh "${WORKSPACE}/${DEVICE}/images/config"
mkdir -p "${WORKSPACE}/super_maker"
mkdir -p "${WORKSPACE}/zip"

move_images_and_calculate_sizes
create_super_image
move_super_image
prepare_device_directory
patch_boot_image
final_steps


