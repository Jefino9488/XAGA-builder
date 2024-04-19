URL="$1"
GITHUB_WORKSPACE="$2"
device="$3"

magiskPatch="$GITHUB_WORKSPACE"/magisk/boot_patch.sh
Red='\033[1;31m'
Yellow='\033[1;33m'
Blue='\033[1;34m'
Green='\033[1;32m'
### System package download
echo -e "${Blue}- Starting downloading recovery rom"
aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "$GITHUB_WORKSPACE" -o "recovery_rom.zip" "${URL}"
echo -e "${Green}- Downloaded recovery rom"

sudo chmod -R 777 "$GITHUB_WORKSPACE/tools"
mkdir -p "$GITHUB_WORKSPACE/${device}"
mkdir -p "$GITHUB_WORKSPACE/super_maker/config"
mkdir -p "$GITHUB_WORKSPACE/zip"

echo -e "${Yellow}- extracting payload.bin"
RECOVERY_ZIP="recovery_rom.zip"
7z x "$GITHUB_WORKSPACE/$RECOVERY_ZIP" -o"$GITHUB_WORKSPACE/${device}" payload.bin
rm -rf "${GITHUB_WORKSPACE:?}/$RECOVERY_ZIP"
echo -e "${Blue}- extracted payload.bin"

### in xaga folder
echo -e "${Yellow}- extracting images"
mkdir -p "$GITHUB_WORKSPACE/${device}/images"
"$GITHUB_WORKSPACE/tools/payload-dumper-go" -o "$GITHUB_WORKSPACE/${device}/images" "$GITHUB_WORKSPACE/${device}/payload.bin" >/dev/null
sudo rm -rf "$GITHUB_WORKSPACE/${device}/payload.bin"
echo -e "${Blue}- extracted images"

# Move images to the super_maker directory
echo -e "${Yellow}- moving images to super_maker"
for i in vendor product system system_ext odm_dlkm odm vendor_dlkm; do
    mv "$GITHUB_WORKSPACE/${device}/images/$i.img" "$GITHUB_WORKSPACE/super_maker/"
    eval "${i}_size=\$(du -sb \"$GITHUB_WORKSPACE/super_maker/$i.img\" | awk {'print \$1'})"
    echo -e "${Blue}- moved $i"
done

# Calculate total size of all images
echo -e "${Yellow}- calculating total size of all images"
super_size=9126805504
total_size=$((system_size + system_ext_size + product_size + vendor_size + odm_size + odm_dlkm_size + vendor_dlkm_size))
echo -e "${Blue}- size of all images"
echo -e "system: $system_size"
echo -e "system_ext: $system_ext_size"
echo -e "product: $product_size"
echo -e "vendor: $vendor_size"
echo -e "odm: $odm_size"
echo -e "odm_dlkm: $odm_dlkm_size"
echo -e "vendor_dlkm: $vendor_dlkm_size"
echo -e "total size: $total_size"

# lpmake command to create super image
echo -e "${Yellow}- creating super image"
"$GITHUB_WORKSPACE"/tools/lpmake --metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 3 \
    --device super:"$super_size" --group main_a:"$total_size" --group main_b:"$total_size" \
    --partition system_a:readonly:"$system_size":main_a --image system_a=./super_maker/system.img \
    --partition system_b:readonly:0:main_b \
    --partition system_ext_a:readonly:"$system_ext_size":main_a --image system_ext_a=./super_maker/system_ext.img \
    --partition system_ext_b:readonly:0:main_b \
    --partition product_a:readonly:"$product_size":main_a --image product_a=./super_maker/product.img \
    --partition product_b:readonly:0:main_b \
    --partition vendor_a:readonly:"$vendor_size":main_a --image vendor_a=./super_maker/vendor.img \
    --partition vendor_b:readonly:0:main_b \
    --partition odm_dlkm_a:readonly:"$odm_dlkm_size":main_a --image odm_dlkm_a=./super_maker/odm_dlkm.img \
    --partition odm_dlkm_b:readonly:0:main_b \
    --partition odm_a:readonly:"$odm_size":main_a --image odm_a=./super_maker/odm.img \
    --partition odm_b:readonly:0:main_b \
    --partition vendor_dlkm_a:readonly:"$vendor_dlkm_size":main_a --image vendor_dlkm_a=./super_maker/vendor_dlkm.img \
    --partition vendor_dlkm_b:readonly:0:main_b \
    --virtual-ab --sparse --output "$GITHUB_WORKSPACE"/super_maker/super.img


if [ $? -ne 0 ]; then
    echo -e "${Red}- failed to create super image"
    exit 1
fi
echo -e "${Blue}- created super image"

# Move super image to the images directory
echo -e "${Yellow}- moving super image"
mv "$GITHUB_WORKSPACE/super_maker/super.img" "$GITHUB_WORKSPACE/${device}/images/"
if [ $? -ne 0 ]; then
    echo -e "${Red}- failed to move super image"
    exit 1
fi
echo -e "${Blue}- moved super image"

echo -e "${Yellow}- ${device} fastboot working directory"
mkdir -p "$GITHUB_WORKSPACE/${device}/boot"
mkdir -p "$GITHUB_WORKSPACE/${device}/vendor_boot"
mkdir -p "$GITHUB_WORKSPACE/zip"

echo -e "${Yellow}- patching boot image"
cp "$GITHUB_WORKSPACE/${device}/images/boot.img" "$GITHUB_WORKSPACE/${device}/boot/"

chmod -R +x "$GITHUB_WORKSPACE/magisk"

$magiskPatch "$GITHUB_WORKSPACE/${device}/boot/boot.img"
if [ $? -ne 0 ]; then
    echo -e "${Red}- failed to patch boot image"
    exit 1
fi
echo -e "${Blue}- patched boot image"

mv "$GITHUB_WORKSPACE/magisk/new-boot.img" "$GITHUB_WORKSPACE/${device}/boot/magisk_boot.img"

mv "$GITHUB_WORKSPACE/${device}/images/boot.img" "$GITHUB_WORKSPACE/${device}/boot/"

mv "$GITHUB_WORKSPACE/${device}/images/vendor_boot.img" "$GITHUB_WORKSPACE/${device}/vendor_boot/"

mv "$GITHUB_WORKSPACE/tools/flasher.exe" "$GITHUB_WORKSPACE/${device}/"

cd "$GITHUB_WORKSPACE" || exit
echo -e "${Blue}- created ${device} working directory"

echo -e "${Yellow}- ziping fastboot files"

zip -r "$GITHUB_WORKSPACE/zip/${device}_fastboot.zip" "${device}"

echo -e "${Green}- ${device}_fastboot.zip created successfully"




