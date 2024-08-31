DEVICE="$1"
WORKSPACE="$2"
FRAMEWORK="$3"

chmod +r "$WORKSPACE"/framework_patcher/*.py
BAKSMALI="${WORKSPACE}/smali/baksmali/build/libs/baksmali.jar"
SMALI="${WORKSPACE}/smali/smali/build/libs/smali.jar"

# move framework files
echo -e "${YELLOW}- moving framework files"
mkdir "${WORKSPACE}/framework_patcher/"
sudo mv "${WORKSPACE}/${DEVICE}/images/system/system/framework/framework.jar" "${WORKSPACE}/framework_patcher/"
sudo mv "${WORKSPACE}/${DEVICE}/images/system/system/framework/services.jar" "${WORKSPACE}/framework_patcher/"
sudo mv "${WORKSPACE}/${DEVICE}/images/system_ext/framework/miui-services.jar" "${WORKSPACE}/framework_patcher/"
sudo mv "${WORKSPACE}/${DEVICE}/images/system_ext/framework/miui-framework.jar" "${WORKSPACE}/framework_patcher/"

# patch framework files
echo -e "${YELLOW}- patching framework files"

# extract framework files
echo -e "${YELLOW}- extracting framework files"

7z x "${WORKSPACE}/framework_patcher/framework.jar" -o"${WORKSPACE}/framework_patcher/framework"
7z x "${WORKSPACE}/framework_patcher/services.jar" -o"${WORKSPACE}/framework_patcher/services"
7z x "${WORKSPACE}/framework_patcher/miui-services.jar" -o"${WORKSPACE}/framework_patcher/miui_services"
7z x "${WORKSPACE}/framework_patcher/miui-framework.jar" -o"${WORKSPACE}/framework_patcher/miui_framework"

# decompile framework files
echo -e "${YELLOW}- decompiling framework dex files"
if [ -f ${WORKSPACE}/framework_patcher/framework/classes.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/framework/classes.dex -o ${WORKSPACE}/framework_patcher/framework/classes
else
  echo -e "${RED}- classes.dex not found in framework.jar"
fi
if [ -f ${WORKSPACE}/framework_patcher/framework/classes2.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/framework/classes2.dex -o ${WORKSPACE}/framework_patcher/framework/classes2
else
  echo -e "${RED}- classes2.dex not found in framework.jar"
fi
if [ -f ${WORKSPACE}/framework_patcher/framework/classes3.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/framework/classes3.dex -o ${WORKSPACE}/framework_patcher/framework/classes3
else
  echo -e "${RED}- classes3.dex not found in framework.jar"
fi
if [ -f ${WORKSPACE}/framework_patcher/framework/classes4.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/framework/classes4.dex -o ${WORKSPACE}/framework_patcher/framework/classes4
else
  echo -e "${RED}- classes4.dex not found in framework.jar"
fi
if [ -f ${WORKSPACE}/framework_patcher/framework/classes5.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/framework/classes5.dex -o ${WORKSPACE}/framework_patcher/framework/classes5
else
  echo -e "${RED}- classes5.dex not found in framework.jar"
fi
echo -e "${BLUE}- decompiled framework dex files"

# decompile services files
echo -e "${YELLOW}- decompiling services dex files"
if [ -f ${WORKSPACE}/framework_patcher/services/classes.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/services/classes.dex -o ${WORKSPACE}/framework_patcher/services/services_classes
else
  echo -e "${RED}- classes.dex not found in services.jar"
fi
if [ -f ${WORKSPACE}/framework_patcher/services/classes2.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/services/classes2.dex -o ${WORKSPACE}/framework_patcher/services/services_classes2
else
  echo -e "${RED}- classes2.dex not found in services.jar"
fi
if [ -f ${WORKSPACE}/framework_patcher/services/classes3.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/services/classes3.dex -o ${WORKSPACE}/framework_patcher/services/services_classes3
else
  echo -e "${RED}- classes3.dex not found in services.jar"
fi
if [ -f ${WORKSPACE}/framework_patcher/services/classes4.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/services/classes4.dex -o ${WORKSPACE}/framework_patcher/services/services_classes4
else
  echo -e "${RED}- classes4.dex not found in services.jar"
fi
if [ -f ${WORKSPACE}/framework_patcher/services/classes5.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/services/classes5.dex -o ${WORKSPACE}/framework_patcher/services/services_classes5
else
  echo -e "${RED}- classes5.dex not found in services.jar"
fi
echo -e "${BLUE}- decompiled services dex files"

# decompile miui_services files
echo -e "${YELLOW}- decompiling miui_services dex files"
if [ -f ${WORKSPACE}/framework_patcher/miui_services/classes.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/miui_services/classes.dex -o ${WORKSPACE}/framework_patcher/miui_services/miui_services_classes
else
  echo -e "${RED}- classes.dex not found in miui-services.jar"
fi
echo -e "${BLUE}- decompiled miui_services dex files"

# decompile miui_framework files
echo -e "${YELLOW}- decompiling miui_framework dex files"
if [ -f ${WORKSPACE}/framework_patcher/miui_framework/classes.dex ]; then
  java -jar "$BAKSMALI" d -a 34 ${WORKSPACE}/framework_patcher/miui_framework/classes.dex -o ${WORKSPACE}/framework_patcher/miui_framework/miui_framework_classes
else
  echo -e "${RED}- classes.dex not found in miui-framework.jar"
fi
echo -e "${BLUE}- decompiled miui_framework dex files"

# patch framework files
echo -e "${YELLOW}- patching framework files"
if [ "$FRAMEWORK" == "core_patch" ]; then
  python3 "${WORKSPACE}/framework_patcher/framework_patch.py"
  python3 "${WORKSPACE}/framework_patcher/services_patch.py"
  python3 "${WORKSPACE}/framework_patcher/miui-service_Patch.py"
  python3 "${WORKSPACE}/framework_patcher/miui-framework_patch.py"
else
  python3 "${WORKSPACE}/framework_patcher/nframework_patch.py"
  python3 "${WORKSPACE}/framework_patcher/nservices_patch.py"
  python3 "${WORKSPACE}/framework_patcher/miui-service_Patch.py"
  python3 "${WORKSPACE}/framework_patcher/miui-framework_patch.py"
fi

# compile framework files
echo -e "${YELLOW}- compiling framework dex files"
if [ -d ${WORKSPACE}/framework_patcher/framework/classes ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/framework/classes -o ${WORKSPACE}/framework_patcher/framework/classes.dex
else
  echo -e "${RED}- classes not found in framework"
fi
if [ -d ${WORKSPACE}/framework_patcher/framework/classes2 ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/framework/classes2 -o ${WORKSPACE}/framework_patcher/framework/classes2.dex
else
  echo -e "${RED}- classes2 not found in framework"
fi
if [ -d ${WORKSPACE}/framework_patcher/framework/classes3 ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/framework/classes3 -o ${WORKSPACE}/framework_patcher/framework/classes3.dex
else
  echo -e "${RED}- classes3 not found in framework"
fi
if [ -d ${WORKSPACE}/framework_patcher/framework/classes4 ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/framework/classes4 -o ${WORKSPACE}/framework_patcher/framework/classes4.dex
else
  echo -e "${RED}- classes4 not found in framework"
fi
if [ -d ${WORKSPACE}/framework_patcher/framework/classes5 ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/framework/classes5 -o ${WORKSPACE}/framework_patcher/framework/classes5.dex
else
  echo -e "${RED}- classes5 not found in framework"
fi
echo -e "${BLUE}- compiled framework dex files"

# compile services files
echo -e "${YELLOW}- compiling services dex files"
if [ -d ${WORKSPACE}/framework_patcher/services/services_classes ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/services/services_classes -o ${WORKSPACE}/framework_patcher/services/classes.dex
else
  echo -e "${RED}- classes not found in services"
fi
if [ -d ${WORKSPACE}/framework_patcher/services/services_classes2 ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/services/services_classes2 -o ${WORKSPACE}/framework_patcher/services/classes2.dex
else
  echo -e "${RED}- classes2 not found in services"
fi
if [ -d ${WORKSPACE}/framework_patcher/services/services_classes3 ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/services/services_classes3 -o ${WORKSPACE}/framework_patcher/services/classes3.dex
else
  echo -e "${RED}- classes3 not found in services"
fi
if [ -d ${WORKSPACE}/framework_patcher/services/services_classes4 ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/services/services_classes4 -o ${WORKSPACE}/framework_patcher/services/classes4.dex
else
  echo -e "${RED}- classes4 not found in services"
fi
if [ -d ${WORKSPACE}/framework_patcher/services/services_classes5 ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/services/services_classes5 -o ${WORKSPACE}/framework_patcher/services/classes5.dex
else
  echo -e "${RED}- classes5 not found in services"
fi
echo -e "${BLUE}- compiled services dex files"

# compile miui_services files
echo -e "${YELLOW}- compiling miui_services dex files"
if [ -d ${WORKSPACE}/framework_patcher/miui_services/miui_services_classes ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/miui_services/miui_services_classes -o ${WORKSPACE}/framework_patcher/miui_services/classes.dex
else
  echo -e "${RED}- classes not found in miui_services"
fi
echo -e "${BLUE}- compiled miui_services dex files"

# compile miui_framework files
echo -e "${YELLOW}- compiling miui_framework dex files"
if [ -d ${WORKSPACE}/framework_patcher/miui_framework/miui_framework_classes ]; then
  java -jar "$SMALI" a ${WORKSPACE}/framework_patcher/miui_framework/miui_framework_classes -o ${WORKSPACE}/framework_patcher/miui_framework/classes.dex
else
  echo -e "${RED}- classes not found in miui_framework"
fi
echo -e "${BLUE}- compiled miui_framework dex files"

# create framework files
echo -e "${YELLOW}- creating framework jar files"
7z a -tzip "${WORKSPACE}/framework_patcher/framework.jar" "${WORKSPACE}/framework_patcher/framework/classes.dex" "${WORKSPACE}/framework_patcher/framework/classes2.dex" "${WORKSPACE}/framework_patcher/framework/classes3.dex" "${WORKSPACE}/framework_patcher/framework/classes4.dex" "${WORKSPACE}/framework_patcher/framework/classes5.dex"
echo -e "${BLUE}- created framework jar files"

# create services files
echo -e "${YELLOW}- creating services jar files"
7z a -tzip "${WORKSPACE}/framework_patcher/services.jar" "${WORKSPACE}/framework_patcher/services/classes.dex" "${WORKSPACE}/framework_patcher/services/classes2.dex" "${WORKSPACE}/framework_patcher/services/classes3.dex" "${WORKSPACE}/framework_patcher/services/classes4.dex" "${WORKSPACE}/framework_patcher/services/classes5.dex"
echo -e "${BLUE}- created services jar files"

# create miui_services files
echo -e "${YELLOW}- creating miui_services jar files"
7z a -tzip "${WORKSPACE}/framework_patcher/miui_services.jar" "${WORKSPACE}/framework_patcher/miui_services/classes.dex"
echo -e "${BLUE}- created miui_services jar files"

# create miui_framework files
echo -e "${YELLOW}- creating miui_framework jar files"
7z a -tzip "${WORKSPACE}/framework_patcher/miui_framework.jar" "${WORKSPACE}/framework_patcher/miui_framework/classes.dex"
echo -e "${BLUE}- created miui_framework jar files"

# move framework files
echo -e "${YELLOW}- moving framework files"
sudo mv -t "${WORKSPACE}/${DEVICE}/images/system_ext/framework/" "${WORKSPACE}/framework_patcher/framework.jar"
sudo mv -t "${WORKSPACE}/${DEVICE}/images/system_ext/framework/" "${WORKSPACE}/framework_patcher/services.jar"
sudo mv -t "${WORKSPACE}/${DEVICE}/images/system/framework/" "${WORKSPACE}/framework_patcher/miui_services.jar"
sudo mv -t "${WORKSPACE}/${DEVICE}/images/system/framework/" "${WORKSPACE}/framework_patcher/miui_framework.jar"
echo -e "${BLUE}- moved framework files"
echo -e "${GREEN}- All done!"