DEVICE="$1"
WORKSPACE="$2"

ls -alh "${WORKSPACE}/${DEVICE}/images/vendor/etc/"

unwanted_files=("voicecommand")
dirs=("/images/vendor/etc/")

for dir in "${dirs[@]}"; do
  for file in "${unwanted_files[@]}"; do
    appsuite=$(find "${WORKSPACE}/${DEVICE}/${dir}/" -type d -name "*$file")
    if [ -d "$appsuite" ]; then
      echo -e "${YELLOW}- removing: $file from $dir"
      sudo rm -rf "$appsuite"
    fi
  done
done