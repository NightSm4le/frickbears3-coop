@echo off
setlocal
title Frickbear's 3 Co-op Installer

set "GAME_DIR=%~dp0.."
set "SOURCE=%~dp0data.win"
set "TARGET=%GAME_DIR%\data.win"
set "BACKUP=%GAME_DIR%\data.win.coop-backup"
set "STAGED=%GAME_DIR%\data.win.coop-new"

if not exist "%GAME_DIR%\Frickbears3.exe" (
    echo ERROR: Put this installer folder directly inside the game folder.
    pause
    exit /b 1
)
if not exist "%SOURCE%" (
    echo ERROR: The co-op data.win is missing beside this BAT file.
    pause
    exit /b 1
)
if not exist "%TARGET%" (
    echo ERROR: The original game data.win was not found.
    pause
    exit /b 1
)

echo.
echo This will replace:
echo   "%TARGET%"
echo.
echo The original will be backed up as:
echo   "%BACKUP%"
echo.
choice /C YN /M "Install this build"
if errorlevel 2 (
    echo Cancelled. Nothing was changed.
    pause
    exit /b 0
)

copy /B /Y "%SOURCE%" "%STAGED%" >nul
if errorlevel 1 (
    echo ERROR: Could not prepare the new data.win. The game was not changed.
    if exist "%STAGED%" del /Q "%STAGED%"
    pause
    exit /b 1
)

if not exist "%BACKUP%" (
    copy /B "%TARGET%" "%BACKUP%" >nul
    if errorlevel 1 (
        echo ERROR: Could not back up the original data.win. The game was not changed.
        del /Q "%STAGED%"
        pause
        exit /b 1
    )
) else (
    echo Existing backup found; it will not be overwritten.
)

move /Y "%STAGED%" "%TARGET%" >nul
if errorlevel 1 (
    echo ERROR: Install failed. The original backup is preserved.
    if exist "%STAGED%" del /Q "%STAGED%"
    pause
    exit /b 1
)

echo.
echo DONE. The co-op build is installed.
echo Original backup: "%BACKUP%"
echo To undo: close the game and restore data.win.coop-backup as data.win.
pause
