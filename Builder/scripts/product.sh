DEVICE="$1"
WORKSPACE="$2"

sudo apt-get install -y cargo
export PATH=$PATH:$HOME/.cargo/bin
cargo install apkeep

RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'

# modify
echo -e "${YELLOW}- modifying product"

unwanted_files=("MiGameService_MTK" "AiAsstVision" "CarWith" "MIUISuperMarket" "MIUIgreenguard" "SogouInput" "VoiceAssistAndroidT" "XiaoaiRecommendation" "MIUIBrowser" "MIUIMusicT" "MIUIVideo" "MiGameCenterSDKService" "VoiceTrigger" "MIUIMiDrive" "MIUIDuokanReader" "MIUIQuickSearchBox" "MIUIHuanji" "MIUIGameCenter" "Health" "MIGalleryLockscreen-MIUI15" "MIMediaEditor" "MIUICalculator" "MIUICleanMaster" "MIUICompass" "MIUIEmail" "MIUINewHome_Removable" "MIUINotes" "MIUIScreenRecorderLite" "MIUISoundRecorderTargetSdk30" "MIUIVipAccount" "MIUIVirtualSim" "MIUIXiaoAiSpeechEngine" "MIUIYoupin" "MiRadio" "MiShop" "MiuiScanner" "SmartHome" "ThirdAppAssistant" "XMRemoteController" "wps-lite" "MiuiDaemon" "MiuiBugReport" "Updater" "MiService" "MiBrowserGlobal" "Music" "XiaomiEUExt" "MiShare" "MiuiVideoGlobal" "GoogleLens" "MiGalleryLockscreen" "MiMover" "PrintSpooler" "CatchLog" "facebook-appmanager" "MIUICompassGlobal" "MIUIHealthGlobal" "MIUIVideoPlayer" "facebook-installer" "facebook-services" "MIShareGlobal" "MIUIMusicGlobal" "MIBrowserGlobal" "MIDrop" "MIUISystemAppUpdater")

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

OUTPATH="${WORKSPACE}/apps"
mkdir -p "${OUTPATH}"
echo -e "${YELLOW}- Downloading the latest Gboard APK"
apkeep -a "com.google.android.inputmethod.latin" "${OUTPATH}/gboard.apk"
mkdir -p "${WORKSPACE}/${DEVICE}/images/product/app/Gboard"
mv "${OUTPATH}/goboard.apk" "${WORKSPACE}/${DEVICE}/images/product/app/Gboard"

ls -alh "${WORKSPACE}/${DEVICE}/images/product/data-app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/app/"
ls -alh "${WORKSPACE}/${DEVICE}/images/product/priv-app/"
echo -e "${BLUE}- modified product"