@echo off
setlocal EnableDelayedExpansion
title UNHUMAN Mod Patcher

:: Change directory to script directory
cd /d "%~dp0"

:: Check for direct command line argument
if not "%~1"=="" (
    set "ACTION=%~1"
    goto :EXECUTE
)

:MENU
cls
echo ============================================================
echo               UNHUMAN QUALITY-OF-LIFE MOD PATCHER           
echo ============================================================
echo.
echo   This patcher modifies package.nw\unhuman.html to include:
echo   - Tutorial Skip Toggle + Instant Rewards ($225k, Lv5, 4 SP, gear, chips)
echo   - Start Screen / Intro Splash Skip Toggle (in Settings + Click/Key Skip)
echo   - Double Click / Right-Click to Equip/Unequip items, Buy Ammo, Apply Codes
echo   - Weapon Hover Magazine Highlighting + Empty Slot Quick-Equip Modal
echo   - Multi-Language Support across 12 Languages (EN, DE, ES, FR, JA, KO, PL, PT, RU, TR, ZH, ZHTW)
echo   - Skills Unspent Points Notification Asterisk on all nav buttons
echo   - Mythic Weapon Upgrades (+1 to +10 Checkpoints, No Deletion, Fairer Odds)
echo   - Nullpoint Abyss Fragment Merging (Safe Failure - Base Fragment Preserved, Fairer Fees)
echo   - Raid Extraction Insanity: Harvest Insanity on extraction (Tier, Kills, Bosses; 0 on death)
echo   - Streamlined Signal Research Station: ASCII combat hidden, clean Masteries/Caches/Wallet view
echo   - Exclusive Raid Weapons: Prototypes/Mythics stripped from caches (caches drop chips, $1.5M, flux)
echo   - Mining Rig Economy Overhaul: 15x Bitcoin yield + 75%% fuel reduction + One-Click Sell All BTC
echo   - Decryption Station & Military Drives: Crack drives instantly for guaranteed crafting codes
echo   - Stash Vault Code Application: Right-click gear -> "Apply Vault Code" directly target-crafts affixes
echo.
echo ============================================================
echo   SELECT AN OPTION:
echo ============================================================
echo   [1] Apply Mod Patch
echo   [2] Restore Original Game (from backup)
echo   [3] Check Mod Status
echo   [4] Exit
echo ============================================================
set /p "CHOICE=Enter choice [1-4]: "

if "%CHOICE%"=="1" set "ACTION=patch" & goto :EXECUTE
if "%CHOICE%"=="2" set "ACTION=restore" & goto :EXECUTE
if "%CHOICE%"=="3" set "ACTION=status" & goto :EXECUTE
if "%CHOICE%"=="4" goto :QUIT
goto :MENU

:EXECUTE
echo.
:: Check if node is available
where node >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    node "%~dp0patcher.js" %ACTION%
) else (
    echo [INFO] Node.js not found in PATH. Using PowerShell engine...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patcher.ps1" -Action %ACTION%
)

echo.
echo ============================================================
echo Press any key to return to menu (or close this window)...
pause >nul
goto :MENU

:QUIT
exit /b 0
