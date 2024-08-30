DEVICE="$1"
WORKSPACE="$2"

sudo chmod +x "${WORKSPACE}/tools/fspatch.py"
sudo chmod +x "${WORKSPACE}/tools/contextpatch.py"
sudo chmod +x "${WORKSPACE}/tools/mkfs.erofs"
sudo chmod +x "${WORKSPACE}/tools/make_ext4fs"

pack_type=EXT

echo -e "${YELLOW}- Repacking images"

# Define partition sizes based on their type
case $partition in
    mi_ext) extraSize=4194304 ;;       # 4 MB
    odm) extraSize=34217728 ;;         # 32.6 MB
    system|vendor|system_ext|product) extraSize=157286400 ;;  # 150 MB
    *) extraSize=8554432 ;;            # Default size for others, 8.15 MB
esac

partitions=("product" "system" "system_ext" "vendor")
for partition in "${partitions[@]}"; do
  echo -e "${Red}- Generating: $partition"

  # Calculate partition size in bytes
  partition_size=$(du -sb "$WORKSPACE/${DEVICE}/images/$partition" | tr -cd 0-9)

  # Calculate total size with extra space
  total_size=$((partition_size + extraSize))

  # Apply patches
  sudo python3 "$WORKSPACE/tools/fspatch.py" "$WORKSPACE/${DEVICE}/images/$partition" "$WORKSPACE/${DEVICE}/images/config/${partition}_fs_config"
  sudo python3 "$WORKSPACE/tools/contextpatch.py" "$WORKSPACE/${DEVICE}/images/$partition" "$WORKSPACE/${DEVICE}/images/config/${partition}_file_contexts"

  # Create filesystem image
  sudo "${WORKSPACE}/tools/make_ext4fs" -J -T "$(date +%s)" -S "$WORKSPACE/${DEVICE}/images/config/${partition}_file_contexts" -C "$WORKSPACE/${DEVICE}/images/config/${partition}_fs_config" -L "$partition" -a "$partition" -l "$total_size" "$WORKSPACE/${DEVICE}/images/${partition}.img" "$WORKSPACE/${DEVICE}/images/$partition"

  # Check if image creation was successful
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create ${partition}.img. Please check if the allocated size is sufficient.${NC}"
    exit 1
  fi

  # Remove original partition directory
  sudo rm -rf "$WORKSPACE/${DEVICE}/images/$partition"
done

echo -e "${Green}- All partitions repacked"


move_images_and_calculate_sizes() {
    echo -e "${YELLOW}- Moving images to super_maker and calculating sizes"
    local IMAGE
    for IMAGE in vendor product system system_ext odm_dlkm odm vendor_dlkm mi_ext; do
        if [ -f "${WORKSPACE}/${DEVICE}/images/$IMAGE.img" ]; then
            mv -t "${WORKSPACE}/super_maker" "${WORKSPACE}/${DEVICE}/images/$IMAGE.img" || exit
            eval "${IMAGE}_size=\$(du -b \"${WORKSPACE}/super_maker/$IMAGE.img\" | awk '{print \$1}')"
            echo -e "${BLUE}- Moved $IMAGE"
        fi
    done

    # Calculate total size of all images
    echo -e "${YELLOW}- Calculating total size of all images"
    super_size=9126805504
    total_size=$((${system_size:-0} + ${system_ext_size:-0} + ${product_size:-0} + ${vendor_size:-0} + ${odm_size:-0} + ${odm_dlkm_size:-0} + ${vendor_dlkm_size:-0} + ${mi_ext_size:-0}))
    echo -e "${BLUE}- Size of all images"
    echo -e "system: ${system_size:-0}"
    echo -e "system_ext: ${system_ext_size:-0}"
    echo -e "product: ${product_size:-0}"
    echo -e "vendor: ${vendor_size:-0}"
    echo -e "odm: ${odm_size:-0}"
    echo -e "odm_dlkm: ${odm_dlkm_size:-0}"
    echo -e "vendor_dlkm: ${vendor_dlkm_size:-0}"
    echo -e "mi_ext: ${mi_ext_size:-0}"
    echo -e "total size: $total_size"
}

create_super_image() {
    echo -e "${YELLOW}- Creating super image"

    lpargs="--metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 3 --device super:${super_size} --group main_a:${super_size} --group main_b:${super_size}"

    for pname in system system_ext product vendor odm_dlkm odm vendor_dlkm mi_ext; do
        if [ -f "${WORKSPACE}/super_maker/${pname}.img" ]; then
            subsize=$(du -sb "${WORKSPACE}/super_maker/${pname}.img" | tr -cd 0-9)
            echo -e "${GREEN}Super sub-partition [$pname] size: [$subsize]"
            lpargs="$lpargs --partition ${pname}_a:readonly:${subsize}:main_a --image ${pname}_a=${WORKSPACE}/super_maker/${pname}.img --partition ${pname}_b:readonly:0:main_b"
        fi
    done

    # Execute the lpmake command with the constructed lpargs
    "${WORKSPACE}/tools/lpmake" $lpargs --virtual-ab --sparse --output "${WORKSPACE}/super_maker/super.img" || exit

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

mkdir -p "${WORKSPACE}/super_maker"
mkdir -p "${WORKSPACE}/zip"

move_images_and_calculate_sizes
create_super_image
move_super_image
prepare_device_directory
final_steps
