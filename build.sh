#!/bin/bash

URL="$1"
GITHUB_WORKSPACE="$2"

device=xaga

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
    echo -e "\e[1;34m - This time $1 took: less than 100 milliseconds \e[0m"
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
    echo -e "\e[1;34m - This time $1 takes: $min minutes $s seconds $ms milliseconds \e[0m"
  elif [[ -n $s ]]; then
    ms=$(expr $ns / 1000000)
    echo -e "\e[1;34m - This time $1 took: $s seconds $ms milliseconds \e[0m"
  else
    ms=$(expr $ns / 1000000)
    echo -e "\e[1;34m - This time $1 took: $ms milliseconds \e[0m"
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
for i in vendor product system system_ext odm_dlkm odm mi_ext vendor_dlkm; do
    mv "$GITHUB_WORKSPACE/${device}/images/$i.img" "$GITHUB_WORKSPACE/super_maker/"
done
# Define the path to the directory containing the image files
image_directory="$GITHUB_WORKSPACE/images"

# Define the list of image files
image_files=("mi_ext.img" "odm.img" "product.img" "system.img" "system_ext.img" "vendor.img" "vendor_dlkm.img")

partition_sizes=""

# Loop through the list of image files
for image_file in "${image_files[@]}"; do
    # Get the full path to the image file
    image_path="$image_directory/$image_file"

    # Check if the file exists
    if [ -e "$image_path" ]; then
        # Get the size of the image file
        image_size=$(du -b "$image_path" | awk '{print $1}')

        # Append the partition configuration to the command
        partition_sizes+="--partition ${image_file%.*}_a:readonly:${image_size}:qti_dynamic_partitions_a --image ${image_file%.*}_a=${image_path} "
        partition_sizes+="--partition ${image_file%.*}_b:readonly:0:qti_dynamic_partitions_b "
    else
        echo "File not found: $image_path"
    fi
done

# Run lpmake command with dynamic sizes
Start_Time
"$GITHUB_WORKSPACE"/tools/lpmake \
  --metadata-size 65536 --super-name super --block-size 4096 \
  $partition_sizes \
  --device super \
  --metadata-slots 3 --group qti_dynamic_partitions_a --group qti_dynamic_partitions_b \
  --virtual-ab -F \
  --output "$GITHUB_WORKSPACE/images/super.img"

for i in mi_ext odm product system system_ext vendor vendor_dlkm; do
  rm -rf "$GITHUB_WORKSPACE/super_maker/$i.img"
done

mv "$GITHUB_WORKSPACE/super_maker/super.img" "$GITHUB_WORKSPACE/${device}/images/"
echo moved super

mkdir -p "$GITHUB_WORKSPACE/${device}/boot"
mkdir -p "$GITHUB_WORKSPACE/${device}/twrp"

mv "$GITHUB_WORKSPACE/${device}/images/boot.img" "$GITHUB_WORKSPACE/${device}/boot/"

mv "$GITHUB_WORKSPACE/${device}/images/vendor_boot.img" "$GITHUB_WORKSPACE/${device}/twrp/"

mv "$GITHUB_WORKSPACE/tools/flasher.exe" "$GITHUB_WORKSPACE/${device}/"

cd "$GITHUB_WORKSPACE" || exit

zip -r "${device}_fastboot.zip" "${device}"
echo "Created ${device}_fastboot.zip"