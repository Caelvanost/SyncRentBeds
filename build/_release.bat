@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0.."

set "PROJECT=%CD%"
set "SKYRIM=C:\Games\Steam\steamapps\common\Skyrim Special Edition"
set "VCPKG=C:\dev\vcpkg"

set "COMPILER=%SKYRIM%\Papyrus Compiler\PapyrusCompiler.exe"
set "FLAGS=%SKYRIM%\Data\Source\Scripts\TESV_Papyrus_Flags.flg"
set "VANILLA_SOURCE=%SKYRIM%\Data\Source\Scripts"

set "PACKAGE=%PROJECT%\package"
set "DIST=%PROJECT%\dist"

set /p VERSION=<"%PROJECT%\VERSION"

echo.
echo ================================================
echo  SyncRentBeds v%VERSION% - Release Build
echo ================================================
echo.

echo [1/5] Configuring...
echo.

cmake -S "%PROJECT%" -B "%PROJECT%\build" ^
    -G "Visual Studio 18 2026" ^
    -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE="%VCPKG%\scripts\buildsystems\vcpkg.cmake"

if errorlevel 1 goto :error

echo.
echo [2/5] Building SKSE plugin...
echo.

cmake --build "%PROJECT%\build" --config Release

if errorlevel 1 goto :error

echo.
echo [3/5] Compiling Papyrus scripts...
echo.

if not exist "%PACKAGE%\Data\Scripts" (
    mkdir "%PACKAGE%\Data\Scripts"
)

del /q "%PACKAGE%\Data\Scripts\RentRoomScript.pex" 2>nul
del /q "%PACKAGE%\Data\Scripts\SyncRentBedsNative.pex" 2>nul

"%COMPILER%" ^
    "%PROJECT%\src\SyncRentBedsNative.psc" ^
    -f="%FLAGS%" ^
    -i="%PROJECT%\src;%VANILLA_SOURCE%" ^
    -o="%PACKAGE%\Data\Scripts"

if errorlevel 1 goto :error

"%COMPILER%" ^
    "%PROJECT%\src\RentRoomScript.psc" ^
    -f="%FLAGS%" ^
    -i="%PROJECT%\src;%VANILLA_SOURCE%" ^
    -o="%PACKAGE%\Data\Scripts"

if errorlevel 1 goto :error

echo.
echo [4/5] Packaging plugin...
echo.

if not exist "%PACKAGE%\Data\SKSE\Plugins" (
    mkdir "%PACKAGE%\Data\SKSE\Plugins"
)

set "DLL="
for /r "%PROJECT%\build" %%F in (SyncRentBeds.dll) do (
    set "DLL=%%F"
)

if not defined DLL (
    echo.
    echo ERROR: SyncRentBeds.dll was not found.
    goto :error
)

copy /y "!DLL!" "%PACKAGE%\Data\SKSE\Plugins\SyncRentBeds.dll" >nul
if errorlevel 1 goto :error

echo.
echo [5/5] Creating release archive...
echo.

if not exist "%DIST%" (
    mkdir "%DIST%"
)

set "ZIP=%DIST%\SyncRentBeds-%VERSION%.zip"
if exist "%ZIP%" del /q "%ZIP%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Compress-Archive -Path '%PACKAGE%\Data' -DestinationPath '%ZIP%' -Force"

if errorlevel 1 goto :error

echo.
echo ================================================
echo  BUILD SUCCESSFUL
echo ================================================
echo.
echo Version: %VERSION%
echo Archive: %ZIP%
echo.
exit /b 0

:error
echo.
echo ================================================
echo  BUILD FAILED
echo ================================================
echo.
echo Check the error above.
echo.
exit /b 1
