@echo off
setlocal

cd /d "%~dp0"
title Libri e Note - Arresto Applicazione
color 0C

echo =====================================================================
echo                ARRESTO LIBRI E NOTE
echo =====================================================================
echo.

echo Chiusura processi in ascolto su porta 13378...

for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":13378" ^| findstr "LISTENING"') do (
    echo Terminazione processo PID: %%a
    taskkill /F /PID %%a >nul 2>nul
)

echo.
echo [OK] Libri e Note e' stato arrestato.
echo.
ping 127.0.0.1 -n 3 >nul
