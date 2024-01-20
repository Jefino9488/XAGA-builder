RECOVERY_ZIP="$1"


sudo chmod -R 777 "tools/"
mkdir -p "xaga/"
mkdir -p "super_maker/"
mkdir -p "zip/"


7z x "$RECOVERY_ZIP" -o"xaga/" payload.bin

### in xaga folder
mkdir -p "xaga/images/"
"tools/payload-dumper-go" -o "xaga/images/" "xaga/payload.bin" >/dev/null
sudo rm -rf "xaga/payload.bin"


# Move images to the super_maker directory
for i in vendor product system system_ext odm_dlkm odm vendor_dlkm; do
    mv "xaga/images/$i.img" "super_maker/"

    # Define the path to the directory containing the image files
    eval "${i}_size=\$(du -sb \"/super_maker/$i.img\" | awk {'print \$1'})"
done

zip_file="tools/fw.zip"
extract_folder="xaga/images"

unzip -q "$zip_file" -d "$extract_folder"

super_size=9126805504
# Calculate total size of all images
total_size=$((system_size + system_ext_size + product_size + vendor_size + odm_size + odm_dlkm_size + vendor_dlkm_size))
# Run lpmake command
tools/lpmake --metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 2 \
    --device super:"$super_size" --group main:"$total_size" \
    --partition system_a:readonly:"$system_size":main --image system_a=super_maker/system.img \
    --partition system_ext_a:readonly:"$system_ext_size":main --image system_ext_a=super_maker/system_ext.img \
    --partition product_a:readonly:"$product_size":main --image product_a=super_maker/product.img \
    --partition vendor_a:readonly:"$vendor_size":main --image vendor_a=super_maker/vendor.img \
    --partition odm_dlkm_a:readonly:"$odm_dlkm_size":main --image odm_dlkm_a=super_maker/odm_dlkm.img \
    --partition odm_a:readonly:"$odm_size":main --image odm_a=super_maker/odm.img \
    --partition vendor_dlkm_a:readonly:"$vendor_dlkm_size":main --image vendor_dlkm_a=super_maker/vendor_dlkm.img \
    --output super_maker/super.img --sparse
echo "Super image created successfully."

mv "super_maker/super.img" "xaga/images/"
echo moved super

mkdir -p "xaga/boot"
mkdir -p "xaga/twrp"
mkdir -p "zip/"

mv "xaga/images/boot.img" "xaga/boot/"

mv "xaga/images/vendor_boot.img" "xaga/twrp/"

mv "tools/flasher.exe" "xaga/"

zip -r "zip/xaga_fastboot.zip" "xaga"

echo "Created xaga_fastboot.zip"



