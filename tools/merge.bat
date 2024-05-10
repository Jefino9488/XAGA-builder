@echo off
setlocal enabledelayedexpansion

set "outputFile=_fastboot.zip"
set "progress=0"
set "totalFiles=0"

rem Count total number of files and store their names in an array
set "files[]="
for /R %%i in (*_fastboot-split.zip) do (
    set /a totalFiles+=1
    set "files[!totalFiles!]=%%i"
)

echo Merging %totalFiles% files into "%outputFile%"

for /L %%i in (1, 1, %totalFiles%) do (
    set "filename=!files[%%i]!_fastboot"
    set "filename=!filename:~0,-4!"

    echo Merging "!files[%%i]!" into "!filename!.zip"
    copy /b "!files[%%i]!" "!filename!.zip" + && del "!files[%%i]!"

    set /a progress+=1
    echo Merged !progress! out of %totalFiles% files
)

echo Merging complete! Output file: %outputFile%
echo Deleting split zip files
del /Q *_fastboot-split.zip
endlocal
pause
