@echo off
title Tiger Tally - Unlock
mode con: cols=70 lines=30
color 0A
echo.
echo  ==========================================================
echo    TIGER TALLY  v3.1   -   UNLOCK
echo  ==========================================================
echo.
echo    You will be asked for:
echo      1) LEFT KEY  (32 chars)
echo      2) password (any ONE of your three)
echo      3) password (any OTHER one of your three)
echo.
echo    Nothing will appear on screen while you type.
echo.
echo  ==========================================================
echo.
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0unlock-triple-key.ps1"
echo.
echo  ==========================================================
echo    DONE. Please read the result above before closing.
echo  ==========================================================
pause