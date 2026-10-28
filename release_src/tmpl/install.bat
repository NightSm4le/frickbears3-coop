@echo off
rem FB3 Co-op test installer: copies the game to a NEW folder and patches the copy. The original is not modified.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
pause
