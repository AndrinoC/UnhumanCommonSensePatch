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
echo.
echo   [1] Tutorial Skip Toggle + Instant Rewards
echo       - Adds toggle in Character Creation screen
echo       - Deactivates tutorial ^& 18 mentor tasks
echo       - Grants all rewards ($225k, Lv5, 4 SP, gear, chips)
echo.
echo   [2] Start Screen / Intro Splash Skip Toggle
echo       - Adds toggle in Game Settings (ON by default)
echo       - Allows instant skip by clicking or pressing any key
echo.
echo   [3] Remove Minigame Auto-Complete Penalty
echo       - Removes -15%% loot penalty in Raid Filters
echo.
echo   [4] Double Click to Equip / Unequip Items
echo       - Double-click items in stash to equip or auto-pack
echo       - Double-click equipped items or augments to unequip
echo.
echo   [5] Right-Click Context Menu Options
echo       - Adds "Equip" option when right-clicking stash items
echo       - Adds "Unequip" option when right-clicking loadout items
echo       - Adds "Buy Ammo" option when right-clicking equipped weapons
echo.
echo   [6] Weapon Hover Magazine Highlighting
echo       - Hovering any weapon highlights compatible magazines in stash & loadout
echo.
echo   [7] Empty Slot Quick-Equip Modal & Trader Direct-Buy
echo       - Click empty loadout slot to view/equip stash items or jump to trader
echo.
echo   [8] Full Multi-Language Support (12 Languages)
echo       - Localized in EN, DE, ES, FR, JA, KO, PL, PT, RU, TR, ZH, ZHTW
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
