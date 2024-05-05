
URL="$1"
GITHUB_WORKSPACE="$2"
device="$3"
key="$4"

Red='\033[1;31m'
Yellow='\033[1;33m'
Blue='\033[1;34m'
Green='\033[1;32m'

### System package download
echo -e "\e[1;31m - Downloading package \e[0m"
aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "$GITHUB_WORKSPACE" -o "recovery_rom.zip" "${URL}"
echo -e "\e[1;31m - Downloaded recovery rom \e[0m"

sudo chmod -R 777 "$GITHUB_WORKSPACE/tools"
mkdir -p "$GITHUB_WORKSPACE/${device}"
mkdir -p "$GITHUB_WORKSPACE/super_maker/config"
mkdir -p "$GITHUB_WORKSPACE/zip"

RECOVERY_ZIP="recovery_rom.zip"
7z x "$GITHUB_WORKSPACE/$RECOVERY_ZIP" -o"$GITHUB_WORKSPACE/${device}" payload.bin
rm -rf "${GITHUB_WORKSPACE:?}/$RECOVERY_ZIP"

### in xaga folder
mkdir -p "$GITHUB_WORKSPACE/${device}/images"
"$GITHUB_WORKSPACE/tools/payload-dumper-go" -o "$GITHUB_WORKSPACE/${device}/images" "$GITHUB_WORKSPACE/${device}/payload.bin" >/dev/null
sudo rm -rf "$GITHUB_WORKSPACE/${device}/payload.bin"

for i in vendor product system system_ext odm_dlkm odm mi_ext vendor_dlkm; do
    mv "$GITHUB_WORKSPACE/${device}/images/$i.img" "$GITHUB_WORKSPACE/super_maker/"

    # Define the path to the directory containing the image files
    eval "${i}_size=\$(du -sb \"$GITHUB_WORKSPACE/super_maker/$i.img\" | awk {'print \$1'})"
done

"$GITHUB_WORKSPACE"/tools/lpmake --metadata-size 65536 --super-name super --block-size 4096 \
--partition mi_ext_a:readonly:"$mi_ext_size":dynamic_partitions_a --image mi_ext_a="$GITHUB_WORKSPACE"/super_maker/mi_ext.img \
--partition mi_ext_b:readonly:0:dynamic_partitions_b \
--partition odm_a:readonly:"$odm_size":dynamic_partitions_a --image odm_a="$GITHUB_WORKSPACE"/super_maker/odm.img \
--partition odm_b:readonly:0:dynamic_partitions_b \
--partition product_a:readonly:"$product_size":dynamic_partitions_a --image product_a="$GITHUB_WORKSPACE"/super_maker/product.img \
--partition product_b:readonly:0:dynamic_partitions_b \
--partition system_a:readonly:"$system_size":dynamic_partitions_a --image system_a="$GITHUB_WORKSPACE"/super_maker/system.img \
--partition system_b:readonly:0:dynamic_partitions_b \
--partition system_ext_a:readonly:"$system_ext_size":dynamic_partitions_a --image system_ext_a="$GITHUB_WORKSPACE"/super_maker/system_ext.img \
--partition system_ext_b:readonly:0:dynamic_partitions_b \
--partition vendor_a:readonly:"$vendor_size":dynamic_partitions_a --image vendor_a="$GITHUB_WORKSPACE"/super_maker/vendor.img \
--partition vendor_b:readonly:0:dynamic_partitions_b \
--partition vendor_dlkm_a:readonly:"$vendor_dlkm_size":dynamic_partitions_a --image vendor_dlkm_a="$GITHUB_WORKSPACE"/super_maker/vendor_dlkm.img \
--partition vendor_dlkm_b:readonly:0:dynamic_partitions_b \
--device super:9126805504 --metadata-slots 3 --group dynamic_partitions_a:9126805504 \
--group dynamic_partitions_b:9126805504 --virtual-ab --output "$GITHUB_WORKSPACE"/super_maker/super.img

mv "$GITHUB_WORKSPACE/super_maker/super.img" "$GITHUB_WORKSPACE/${device}/images/"
echo moved super

mkdir -p "$GITHUB_WORKSPACE/${device}/boot"
mkdir -p "$GITHUB_WORKSPACE/${device}/vendor_boot"
mkdir -p "$GITHUB_WORKSPACE/zip"

magiskPatch="$GITHUB_WORKSPACE"/magisk/boot_patch.sh

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

cp "$GITHUB_WORKSPACE/tools/preloader_ari.bin" "$GITHUB_WORKSPACE/${device}/images/"

if [ -f "$GITHUB_WORKSPACE/${device}/images/preloader_ari.bin" ]; then
    echo -e "${Green}preloader_ari.bin copied successfully"
else
    echo -e "${Red}Failed to copy preloader_ari.bin"
fi
cd "$GITHUB_WORKSPACE" || exit
zip -r "$GITHUB_WORKSPACE/zip/${device}_fastboot.zip" "${device}"

echo -e "${Green}- ${device}_fastboot.zip created successfully"
