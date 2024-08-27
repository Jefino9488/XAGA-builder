sudo apt-get remove -y firefox zstd
sudo apt-get install python3 aria2

URL="$1"
DEVICE="$2"
WORKSPACE="$3"

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

# decompress images
echo -e "${YELLOW}- decompressing images"
mkdir -p "${WORKSPACE}/${DEVICE}/images/decompressed"
for img in product system system_ext vendor odm; do
    "${WORKSPACE}/tools/sdat2img" "${WORKSPACE}/${DEVICE}/images/$img.img" "${WORKSPACE}/${DEVICE}/images/decompressed/$img.img" || exit
    echo -e "${BLUE}- decompressed $img"
done

# list all content 

echo -e "${YELLOW}- listing all content"
ls -alh "${WORKSPACE}/${DEVICE}/images/decompressed"
ls -alh "${WORKSPACE}/${DEVICE}/images"

# Clean up
rm -rf "${WORKSPACE:?}/${DEVICE:?}/images"
rm -rf "${WORKSPACE:?}/${DEVICE:?}/payload.bin"
rm -rf "${WORKSPACE:?}/${DEVICE:?}/recovery_rom.zip"
echo -e "${GREEN}- Cleaned up"