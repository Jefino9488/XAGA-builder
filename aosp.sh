URL="$1"
GITHUB_WORKSPACE="$2"
device="$3"


Start_Time() {
  Start_ns=$(date +'%s%N')
}

End_Time() {
  # Hours, minutes, seconds, milliseconds, nanoseconds
  local h min s ms ns end_ns time
  End_ns=$(date +'%s%N')
  time=$(expr $End_ns - $Start_ns)
  [[ -z "$time" ]] && return 0
  ns=${time:0-9}
  s=${time%$ns}
  if [[ $s -ge 10800 ]]; then
    echo -e "\e[1;34m - Time $1 took: less than 100 milliseconds \e[0m"
  elif [[ $s -ge 3600 ]]; then
    ms=$(expr $ns / 1000000)
    h=$(expr $s / 3600)
    h=$(expr $s % 3600)
    if [[ $s -ge 60 ]]; then
      min=$(expr $s / 60)
      s=$(expr $s % 60)
    fi
    echo -e "\e[1;34m - This $1 time: $h hours $min minutes $s seconds $ms milliseconds \e[0m"
  elif [[ $s -ge 60 ]]; then
    ms=$(expr $ns / 1000000)
    min=$(expr $s / 60)
    s=$(expr $s % 60)
    echo -e "\e[1;34m - Time $1 took: $min minutes $s seconds $ms milliseconds \e[0m"
  elif [[ -n $s ]]; then
    ms=$(expr $ns / 1000000)
    echo -e "\e[1;34m - Time $1 took: $s seconds $ms milliseconds \e[0m"
  else
    ms=$(expr $ns / 1000000)
    echo -e "\e[1;34m - Time $1 took: $ms milliseconds \e[0m"
  fi
}


### System package download
echo -e "\e[1;31m - Start downloading package \e[0m"
Start_Time
aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "$GITHUB_WORKSPACE" -o "recovery_rom.zip" "${URL}"
End_Time Downloaded recovery rom

Start_Time
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
End_Time

# Move images to the super_maker directory
for i in vendor product system system_ext odm_dlkm odm vendor_dlkm; do
    mv "$GITHUB_WORKSPACE/${device}/images/$i.img" "$GITHUB_WORKSPACE/super_maker/"

    # Define the path to the directory containing the image files
    eval "${i}_size=\$(du -sb \"$GITHUB_WORKSPACE/super_maker/$i.img\" | awk {'print \$1'})"
done

zip_file="$GITHUB_WORKSPACE/tools/fw.zip"
extract_folder="$GITHUB_WORKSPACE/${device}/images"

unzip -q "$zip_file" -d "$extract_folder"

super_size=9126805504
# Calculate total size of all images
total_size=$((system_size + system_ext_size + product_size + vendor_size + odm_size + odm_dlkm_size + vendor_dlkm_size))
Start_Time
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

End_Time super

if [ $? -ne 0 ]; then
    echo "Error: Failed to create super image."
    exit 1
fi
echo "Super image created successfully."

mv "$GITHUB_WORKSPACE/super_maker/super.img" "$GITHUB_WORKSPACE/${device}/images/"
echo moved super

mkdir -p "$GITHUB_WORKSPACE/${device}/boot"
mkdir -p "$GITHUB_WORKSPACE/${device}/twrp"
mkdir -p "$GITHUB_WORKSPACE/zip"

mv "$GITHUB_WORKSPACE/${device}/images/boot.img" "$GITHUB_WORKSPACE/${device}/boot/"

mv "$GITHUB_WORKSPACE/${device}/images/vendor_boot.img" "$GITHUB_WORKSPACE/${device}/twrp/"

mv "$GITHUB_WORKSPACE/tools/flasher.exe" "$GITHUB_WORKSPACE/${device}/"

cd "$GITHUB_WORKSPACE" || exit
zip -r "$GITHUB_WORKSPACE/zip/${device}_fastboot.zip" "${device}"

echo "Created ${device}_fastboot.zip"




















