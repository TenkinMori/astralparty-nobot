@echo off
chcp 65001 >nul
setlocal

cd /d "%~dp0"

echo.
echo ============================================
echo   NoBotStarter - 开房间不补 Bot
echo ============================================
echo.
echo   1. 安装
echo   2. 还原原版
echo   3. 查看状态
echo   4. 退出
echo.
set /p CHOICE=请选择 [1-4]:

if "%CHOICE%"=="1" goto INSTALL
if "%CHOICE%"=="2" goto RESTORE
if "%CHOICE%"=="3" goto STATUS
if "%CHOICE%"=="4" goto END
echo 输入无效
pause
goto END

:INSTALL
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-nobot.ps1"
goto END

:RESTORE
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-nobot.ps1" -Restore
goto END

:STATUS
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-nobot.ps1" -Status
goto END

:END
echo.
pause
endlocal