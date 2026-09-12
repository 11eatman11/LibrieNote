@echo off
setlocal enabledelayedexpansion

:: Posizionamento nella cartella dello script
cd /d "%~dp0"

title Libri e Note - Studio Digitale
color 0B

echo =====================================================================
echo                LIBRI E NOTE - STUDIO DIGITALE
echo =====================================================================
echo.

:: 1. Controllo presenza di Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERRORE] Node.js non e' installato o non e' presente nel PATH di sistema.
    echo Scarica e installa Node.js da: https://nodejs.org
    echo.
    pause
    exit /b 1
)

:: 2. Verifica e installazione dipendenze server
if not exist "node_modules" (
    echo [1/3] Installazione dipendenze server in corso...
    call npm install
    if %errorlevel% neq 0 (
        echo [ERRORE] Impossibile installare le dipendenze del server.
        pause
        exit /b 1
    )
)

:: 3. Verifica e installazione dipendenze client
if not exist "client\node_modules" (
    echo [2/3] Installazione dipendenze client in corso...
    cd client
    call npm install
    cd ..
    if %errorlevel% neq 0 (
        echo [ERRORE] Impossibile installare le dipendenze client.
        pause
        exit /b 1
    )
)

:: 4. Verifica compilazione build client
if not exist "client\dist" (
    echo [3/3] Compilazione interfaccia web in corso...
    cd client
    call npm run generate
    cd ..
)

:: 5. Creazione cartelle di lavoro se non esistono
if not exist "config" mkdir "config"
if not exist "metadata" mkdir "metadata"

echo.
echo =====================================================================
echo  [OK] Avvio di Libri e Note in corso sulla porta 13378...
echo  Indirizzo web: http://localhost:13378
echo  (Lascia aperta questa finestra mentre usi l'applicazione)
echo  Premi CTRL+C per arrestare il server.
echo =====================================================================
echo.

:: Variabili di configurazione
set "PORT=13378"
set "HOST=0.0.0.0"
set "CONFIG_PATH=%~dp0config"
set "METADATA_PATH=%~dp0metadata"

:: Apertura automatica nel browser
start "" cmd /c "timeout /t 3 >nul & start http://localhost:13378"

:: Avvio effettivo del server
node index.js --port 13378 --config "%CONFIG_PATH%" --metadata "%METADATA_PATH%"

echo.
echo Il server e' stato arrestato.
pause
