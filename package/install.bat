@echo off
rem TF3-DLSS installer: registers the Vulkan layer in this folder for the current Windows user.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bin\tf3_dlss_setup.ps1" install
echo.
pause
