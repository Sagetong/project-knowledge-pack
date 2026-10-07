@echo off
title Tiger Tally - Setup
mode con: cols=70 lines=30
color 0E
echo.
echo  ==========================================================
echo    TIGER TALLY  v3.1   -   SET UP YOUR THREE PASSWORDS
echo  ==========================================================
echo.
echo    You will be asked for:
echo      1) LEFT KEY   (32 chars, given by the AI)
echo      2) your password #1
echo      3) your password #2
echo      4) your password #3
echo.
echo    Nothing will appear on screen while you type.
echo    That is normal. It prevents shoulder-surfing.
echo.
echo    You only need to remember: ANY TWO of your three
echo    passwords will unlock it later.
echo.
echo  ==========================================================
echo.
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0init-triple-key.ps1"
echo.
echo  ==========================================================
echo    DONE. Please read the result above before closing.
echo  ==========================================================
pause