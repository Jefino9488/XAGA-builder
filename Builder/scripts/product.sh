DEVICE="$1"
WORKSPACE="$2"
REGION="$3"

RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'

# Modify
echo -e "${YELLOW}- modifying product"

if [ "$REGION" == "CN" ]; then
  unwanted_files=("XiaoaiEdgeEngine" "MIUIAiasstService" "MIUIGuardProvider" "MINextpay" "MiGameService_MTK" "AiAsstVision" "CarWith" "MIUISuperMarket" "MIUIgreenguard" "SogouInput" "VoiceAssistAndroidT" "XiaoaiRecommendation" "Updater" "CatchLog" "MIUIBrowser" "MIUIMusicT" "MIUIVideo" "MiGameCenterSDKService" "VoiceTrigger" "MIUIQuickSearchBox" "MIUIMiDrive" "MIUIDuokanReader" "MIUIHuanji" "MIUIGameCenter" "Health" "MIGalleryLockscreen-MIUI15" "MIMediaEditor" "MIUICalculator" "MIUICleanMaster" "MIUICompass" "MIUIEmail" "MIUINewHome_Removable" "MIUINotes" "MIUIScreenRecorderLite" "MIUISoundRecorderTargetSdk30" "MIUIVipAccount" "MIUIVirtualSim" "MIUIXiaoAiSpeechEngine" "MIUIYoupin" "MiRadio" "MiShop" "MiuiScanner" "SmartHome" "ThirdAppAssistant" "XMRemoteController" "com.iflytek.inputmethod.miui" "wps-lite" "BaiduIME")
else
  unwanted_files=("Drive" "GlobalWPSLITE" "MIDrop" "MIMediaEditorGlobal" "MISTORE_OVERSEA" "MIUICalculatorGlobal" "MIUICompassGlobal" "MIUINotes" "MIUIScreenRecorderLiteGlobal" "MIUISoundRecorderTargetSdk30Global" "MIUIWeatherGlobal" "Meet" "MiCare" "MiGalleryLockScreenGlobal" "MicrosoftOneDrive" "MiuiScanner" "Opera" "Photos" "SmartHome" "Videos" "XMRemoteController" "YTMusic" "Gmail2" "MIRadioGlobal" "MIUIHealthGlobal" "MIUIMiPicks" "Maps" "PlayAutoInstallStubApp" "Updater" "YouTube" "AndroidAutoStub" "MIUIMusicGlobal" "Velvet" "")
fi


dirs=("images/product/app" "images/product/priv-app" "images/product/data-app")

for dir in "${dirs[@]}"; do
  for file in "${unwanted_files[@]}"; do
    appsuite=$(find "${WORKSPACE}/${DEVICE}/${dir}/" -type d -name "*$file")
    if [ -d "$appsuite" ]; then
      echo -e "${YELLOW}- removing: $file from $dir"
      sudo rm -rf "$appsuite"
    fi
  done
done

# Add Gboard only if the region is CN
if [ "$REGION" == "CN" ]; then
  mkdir -p "${WORKSPACE}/${DEVICE}/images/product/priv-app/Gboard"
  mv "${WORKSPACE}/Builder/apps/gboard.apk" "${WORKSPACE}/${DEVICE}/images/product/priv-app/Gboard/"
  mv "${WORKSPACE}/Builder/permisions/privapp_whitelist_com.google.android.inputmethod.latin.xml" "${WORKSPACE}/${DEVICE}/images/product/etc/permissions/"
  echo -e "${GREEN}Gboard added"
fi

ls -alh "${WORKSPACE}/${DEVICE}/images/product/data-app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/priv-app/"
echo -e "${BLUE}- modified product"
