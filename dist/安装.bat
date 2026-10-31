@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo ============================================
echo   NoBotStarter - 开房间不补 Bot
echo ============================================
echo.
echo   1. 安装
echo   2. 还原
echo   3. 退出
echo.
set /p C=请选择 [1-3]:
if "%C%"=="1" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if "%C%"=="2" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Restore
pause
endlocal