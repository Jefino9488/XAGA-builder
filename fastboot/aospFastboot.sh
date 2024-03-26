URL="$1"
GITHUB_WORKSPACE="$2"
device="$3"

magiskPatch="$GITHUB_WORKSPACE"/magisk/boot_patch.sh


### System package download
echo -e "\e[1;31m - Start downloading package \e[0m"
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

# Move images to the super_maker directory
for i in vendor product system system_ext odm_dlkm odm vendor_dlkm; do
    mv "$GITHUB_WORKSPACE/${device}/images/$i.img" "$GITHUB_WORKSPACE/super_maker/"

    # Define the path to the directory containing the image files
    eval "${i}_size=\$(du -sb \"$GITHUB_WORKSPACE/super_maker/$i.img\" | awk {'print \$1'})"
done

super_size=9126805504
# Calculate total size of all images
total_size=$((system_size + system_ext_size + product_size + vendor_size + odm_size + odm_dlkm_size + vendor_dlkm_size))

# Run lpmake command
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
echo -e "\e[1;31m - Super image created successfully. \e[0m"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create super image."
    exit 1
fi
echo "Super image created successfully."

mv "$GITHUB_WORKSPACE/super_maker/super.img" "$GITHUB_WORKSPACE/${device}/images/"
echo moved super

mkdir -p "$GITHUB_WORKSPACE/${device}/boot"
mkdir -p "$GITHUB_WORKSPACE/${device}/vendor_boot"
mkdir -p "$GITHUB_WORKSPACE/zip"

mv "$GITHUB_WORKSPACE/${device}/images/boot.img" "$GITHUB_WORKSPACE/${device}/boot/"

mv "$GITHUB_WORKSPACE/${device}/images/vendor_boot.img" "$GITHUB_WORKSPACE/${device}/vendor_boot/"

mv "$GITHUB_WORKSPACE/tools/flasher.exe" "$GITHUB_WORKSPACE/${device}/"

cd "$GITHUB_WORKSPACE" || exit
zip -r "$GITHUB_WORKSPACE/zip/${device}_fastboot.zip" "${device}"

echo "Created ${device}_fastboot.zip"




