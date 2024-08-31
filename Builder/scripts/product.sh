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
  APK_URL="https://eb5e7388c3df147b74dd2379b7cf8323.r2.cloudflarestorage.com/downloadprod/wp-content/uploads/2024/08/18/66bc4c651cd8d/com.google.android.inputmethod.latin_14.5.04.655125648-release-arm64-v8a-149760070_minAPI26%28arm64-v8a%29%28nodpi%29_apkmirror.com.apk?X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=72a5ba3a0b8a601e535d5525f12f8177%2F20240831%2Fauto%2Fs3%2Faws4_request&X-Amz-Date=20240831T044044Z&X-Amz-SignedHeaders=host&X-Amz-Expires=3600&X-Amz-Signature=7bd3772af46e20221ace8292edb560ce1e4c647cead60e11256b105d76e99798"
  DEST_DIR="${WORKSPACE}/Builder/apps"
  DEST_FILE="goboard.apk"

  mkdir -p "$DEST_DIR"
  aria2c -x16 -d "$DEST_DIR" -o "$DEST_FILE" "$APK_URL"
  if [ -f "$DEST_DIR/$DEST_FILE" ]; then
      echo "Download successful: $DEST_DIR/$DEST_FILE"
  else
      echo "Download failed"
  fi

  mkdir -p "${WORKSPACE}/${DEVICE}/images/product/priv-app/Gboard"
  mv "${WORKSPACE}/Builder/apps/goboard.apk" "${WORKSPACE}/${DEVICE}/images/product/priv-app/Gboard/"
  mv "${WORKSPACE}/Builder/permisions/privapp_whitelist_com.google.android.inputmethod.latin.xml" "${WORKSPACE}/${DEVICE}/images/product/etc/permissions/"
  echo -e "${GREEN}Gboard added for CN region"
fi

ls -alh "${WORKSPACE}/${DEVICE}/images/product/data-app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/priv-app/"
echo -e "${BLUE}- modified product"
