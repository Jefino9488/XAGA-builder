DEVICE="$1"
WORKSPACE="$2"

## Install apkeep
#sudo apt-get install -y cargo
#cargo install apkeep

# modify
echo -e "${YELLOW}- modifying product"

unwanted_files=("MiGameService_MTK" "AiAsstVision" "CarWith" "MIUISuperMarket" "MIUIgreenguard" "SogouInput" "VoiceAssistAndroidT" "XiaoaiRecommendation" "MIUIBrowser" "MIUIMusicT" "MIUIVideo" "MiGameCenterSDKService" "VoiceTrigger" "MIUIMiDrive" "MIUIDuokanReader" "MIUIQuickSearchBox" "MIUIHuanji" "MIUIGameCenter" "Health" "MIGalleryLockscreen-MIUI15" "MIMediaEditor" "MIUICalculator" "MIUICleanMaster" "MIUICompass" "MIUIEmail" "MIUINewHome_Removable" "MIUINotes" "MIUIScreenRecorderLite" "MIUISoundRecorderTargetSdk30" "MIUIVipAccount" "MIUIVirtualSim" "MIUIXiaoAiSpeechEngine" "MIUIYoupin" "MiRadio" "MiShop" "MiuiScanner" "SmartHome" "ThirdAppAssistant" "XMRemoteController" "com.iflytek.inputmethod.miui" "wps-lite" "BaiduIME" "MiuiDaemon" "MiuiBugReport" "Updater" "MiService" "MiBrowserGlobal" "Music" "XiaomiEUExt" "MiShare" "MiuiVideoGlobal" "GoogleLens" "MiGalleryLockscreen" "MiMover" "PrintSpooler" "CatchLog" "facebook-appmanager" "MIUICompassGlobal" "MIUIHealthGlobal" "MIUIVideoPlayer" "facebook-installer" "facebook-services" "MIShareGlobal" "MIUIMusicGlobal" "MIBrowserGlobal" "MIDrop" "MIUISystemAppUpdater")

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

echo -e "${YELLOW}- Downloading the latest Gboard APK"
#apkeep -a "com.google.android.inputmethod.latin" -o "${WORKSPACE}/apps/goboard.apk"
#mkdir -p "${WORKSPACE}/${DEVICE}/images/product/app/Gboard"
#mv "${WORKSPACE}/apps/goboard.apk" "${WORKSPACE}/${DEVICE}/images/product/app/Gboard"

ls -alh "${WORKSPACE}/${DEVICE}/images/product/data-app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/priv-app/"
echo -e "${BLUE}- modified product"