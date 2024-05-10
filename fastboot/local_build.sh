#!/bin/bash

# Check if a recovery zip file was provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <recovery_zip>"
  exit 1
fi

# Set the path to the recovery zip file
recovery_zip="$1"

# Set the path to the tools directory
tools_dir="tools"

# Set the path to the output directory
output_dir="xaga"

# Set the path to the super_maker directory
super_maker_dir="super_maker"

# Set the path to the zip directory
zip_dir="zip"

# Set the path to the log file
log_file="${zip_dir}/lpmake.log"

# Change the ownership of the necessary directories to the current user
sudo chown -R "$(whoami):$(whoami)" "${tools_dir}" "${output_dir}" "${super_maker_dir}" "${zip_dir}"

# Make the necessary directories
mkdir -p "${output_dir}" "${super_maker_dir}" "${zip_dir}" || exit 1

# Extract the recovery zip file to a temporary directory
tmp_dir="$(mktemp -d)"
7z x -y "${recovery_zip}" -o"${tmp_dir}" payload.bin || exit 1

# Move the payload.bin file to the xaga directory
mv "${tmp_dir}/payload.bin" "${output_dir}/" || exit 1

# Use the payload-dumper-go tool to extract the images from payload.bin
"${tools_dir}/payload-dumper-go" -o "${output_dir}/images/" "${output_dir}/payload.bin" >/dev/null || exit 1

# Remove the payload.bin file
rm -f "${output_dir}/payload.bin"

# Move the images to the super_maker directory
for img in vendor product system system_ext odm_dlkm odm vendor_dlkm; do
  mv "${output_dir}/images/${img}.img" "${super_maker_dir}/" || exit 1

  # Define the path to the directory containing the image files
  eval "${img}_size=$(du -m "${super_maker_dir}/${img}.img" | awk '{print $1}')"
done

# Calculate the total size of all images with decimal precision
total_size=$(bc -l <<< "scale=2; ${system_size} + ${system_ext_size} + ${product_size} + ${vendor_size} + ${odm_size} + ${odm_dlkm_size} + ${vendor_dlkm_size}")

# Run the lpmake command and redirect the output to both the console and a log file
"${tools_dir}/lpmake" --metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 2 \
  --device super:"${super_size}" --group main_a:"${total_size}" --group main_b:"${total_size}" \
  --partition system_a:readonly:"${system_size}":main_a --image system_a="${super_maker_dir}/system.img" \
  --partition system_b:readonly:0:main_b \
  --partition system_ext_a:readonly:"${system_ext_size}":main_a --image system_ext_a="${super_maker_dir}/system_ext.img" \
  --partition system_ext_b:readonly:0:main_b \
  --partition product_a:readonly:"${product_size}":main_a --image product_a="${super_maker_dir}/product.img" \
  --partition product_b:readonly:0:main_b \
  --partition vendor_a:readonly:"${vendor_size}":main_a --image vendor_a="${super_maker_dir}/vendor.img" \
  --partition vendor_b:readonly:0:main_b \
  --partition odm_dlkm_a:readonly:"${odm_dlkm_size}":main_a --image odm_dlkm_a="${super_maker_dir}/odm_dlkm.img" \
  --partition odm_dlkm_b:readonly:0:main_b \
  --partition odm_a:readonly:"${odm_size}":main_a --image odm_a="${super_maker_dir}/odm.img" \
  --partition odm_b:readonly:0:main_b \
  --partition vendor_dlkm_a:readonly:"${vendor_dlkm_size}":main_a --image vendor_dlkm_a="${super_maker_dir}/vendor_dlkm.img" \
  --partition vendor_dlkm_b:readonly:0:main_b \
  --output "${super_maker_dir}/super.img" --sparse | tee "${log_file}"

# Check if the lpmake command was successful
if [ $? -eq 0 ]; then
  echo "Super image created successfully."

  # Move the super.img file to the xaga/images directory
  mv "${super_maker_dir}/super.img" "${output_dir}/images/" || exit 1

  # Create the necessary directories for the xaga_fastboot.zip file
  mkdir -p "${output_dir}/boot" "${output_dir}/twrp" || exit 1

  # Move the boot and vendor_boot images to their respective directories
  mv "${output_dir}/images/boot.img" "${output_dir}/boot/" || exit 1
  mv "${output_dir}/images/vendor_boot.img" "${output_dir}/twrp/" || exit 1

  # Move the flasher.exe tool to the xaga directory
  mv "${tools_dir}/flasher.exe" "${output_dir}/" || exit 1

  # Create the xaga_fastboot.zip file
  zip -r "${zip_dir}/xaga_fastboot.zip" "${output_dir}" || exit 1

  echo "Created xaga_fastboot.zip"
else
  echo "Error: lpmake command failed. Check the log file for details."
  exit 1
fi
