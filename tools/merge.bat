@echo off
setlocal enabledelayedexpansion

set "outputFile=_fastboot.zip"
set "progress=0"
set "totalFiles=0"

rem Count total number of files
for /R %%i in (*_fastboot-split.zip) do (
    set /a totalFiles+=1
)

echo Merging %totalFiles% files into "%outputFile%"

for /R %%i in (*_fastboot-split.zip) do (
    set "filename=%%~ni"
    set "filename=!filename:_fastboot-split=!"

    echo Merging "!filename!!outputFile!"
    copy /b "%%i" "!filename!!outputFile!" + && del "%%i"

    set /a progress+=1
    echo Merged !progress! out of %totalFiles% files
)

echo Merging complete! Output file: %outputFile%
echo Deleting split zip files
del /Q *_fastboot-split.zip
endlocal
pause
