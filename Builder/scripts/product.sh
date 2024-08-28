
DEVICE="$1"
WORKSPACE="$2"
# modify
echo -e "${YELLOW}- modifying product"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/data-app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/data-app/system"
unwanted_files=("MIUIMiDrive" "MIUIDuokanReader" "MIUIQuickSearchBox" "MIUIHuanji" "MIUIGameCenter" "Health" "MIGalleryLockscreen-MIUI15" "MIMediaEditor" "MIUICalculator" "MIUICleanMaster" "MIUICompass" "MIUIEmail" "MIUINewHome_Removable" "MIUINotes" "MIUIScreenRecorderLite" "MIUISoundRecorderTargetSdk30" "MIUIVipAccount" "MIUIVirtualSim" "MIUIWeather" "MIUIXiaoAiSpeechEngine" "MIUIYoupin" "MiRadio" "MiShop" "MiuiScanner" "SmartHome" "ThirdAppAssistant" "XMRemoteController" "com.iflytek.inputmethod.miui" "wps-lite" "BaiduIME")

for file in "${unwanted_files[@]}"; do
  appsuite=$(find "${WORKSPACE}/${DEVICE}/images/product/data-app/" -type d -name "*$file")
  if [ -d "$appsuite" ]; then
    echo -e "${YELLOW}- removing: $file"
    sudo rm -rf "$appsuite"
  fi
done
echo -e "${BLUE}- modified product"