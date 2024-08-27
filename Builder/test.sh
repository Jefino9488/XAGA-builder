sudo apt-get remove -y firefox zstd
sudo apt-get install python3 aria2

URL="$1"
DEVICE="$2"
WORKSPACE="$3"

# Set Permissions and create directories
sudo chmod -R +rwx "${GITHUB_WORKSPACE}/tools"

# Grant execution permissions to the tools
sudo chmod +x "${WORKSPACE}/tools/payload-dumper-go"
sudo chmod +x "${WORKSPACE}/tools/erofs_extract"

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

# Create decompressed images directory
mkdir -p "${WORKSPACE}/${DEVICE}/images/decompressed"

# Decompress images to eimages/decompressed directory
echo -e "${YELLOW}- decompressing images"
for i in product system system_ext; do
  echo -e "${YELLOW}- Decomposing ported package: $i"
  sudo "${WORKSPACE}/tools/erofs_extract" -s -i "${WORKSPACE}/${DEVICE}/images/$i.img" -x -o "${WORKSPACE}/${DEVICE}/images/decompressed"
  rm -rf "${WORKSPACE}/${DEVICE}/images/$i.img"
  echo -e "${BLUE}- decompressed $i"
done

# List all content
echo -e "${YELLOW}- listing all content"
ls -alh "${WORKSPACE}/${DEVICE}/images/decompressed"
ls -alh "${WORKSPACE}/${DEVICE}/images"

# Clean up
rm -rf "${WORKSPACE:?}/${DEVICE:?}/images"
rm -rf "${WORKSPACE:?}/${DEVICE:?}/payload.bin"
rm -rf "${WORKSPACE:?}/${DEVICE:?}/recovery_rom.zip"
echo -e "${GREEN}- Cleaned up"
