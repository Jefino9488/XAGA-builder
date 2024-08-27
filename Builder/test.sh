sudo apt-get remove -y firefox zstd
sudo apt-get install python3 aria2

URL="$1"
DEVICE="$2"
WORKSPACE="$3"

# Set Permissions and create directories
sudo chmod -R +rwx "${GITHUB_WORKSPACE}/tools"

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

# Decompress images to eimages/decompressed directory
echo -e "${YELLOW}- decompressing images"
for i in product system system_ext; do
  echo -e "${YELLOW}- Decomposing ported package: $i"
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
  eval "${partition}_size=$(du -sb "$WORKSPACE"/"${DEVICE}"/images/$partition.img | awk '{print $1}')"
  sudo rm -rf "$WORKSPACE"/"${DEVICE}"/images/$partition
done

echo -e "${Green}- All partitions repacked"


# List all content
echo -e "${YELLOW}- listing all content"
ls -alh "${WORKSPACE}/${DEVICE}/images"

# Clean up
rm -rf "${WORKSPACE:?}/${DEVICE:?}/images"
rm -rf "${WORKSPACE:?}/${DEVICE:?}/payload.bin"
rm -rf "${WORKSPACE:?}/${DEVICE:?}/recovery_rom.zip"
echo -e "${GREEN}- Cleaned up"
