@echo off
rem TF3-DLSS uninstaller: removes the Vulkan layer registration for the current Windows user.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bin\tf3_dlss_setup.ps1" uninstall
echo.
pause
