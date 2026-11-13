@echo off
chcp 65001 >nul
cd /d "%~dp0"
if "%~1"=="" (
    python tools\nobot_tool.py --install
) else (
    python tools\nobot_tool.py --game "%~1" --install
)
echo.
pause
