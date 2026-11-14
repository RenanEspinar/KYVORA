@echo off
setlocal
set "LIFTLOG_ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "LIFTLOG_APK=%~dp0LIFTLOG-1.0-pruebas.apk"
set "LIFTLOG_SHA256=310910be4949c346884ee7018f5c97c4959d2f8f57265351e1ab7f3b54b908f5"
set "LIFTLOG_LOG=%~dp0instalacion.log"
echo LIFTLOG - Instalacion Android por USB
if not exist "%LIFTLOG_ADB%" goto no_adb
if not exist "%LIFTLOG_APK%" goto no_apk
echo Comprobando integridad de la APK...
powershell.exe -NoProfile -Command "$liftlogHash=(Get-FileHash -LiteralPath $env:LIFTLOG_APK -Algorithm SHA256 -ErrorAction Stop).Hash; if ($liftlogHash -ne $env:LIFTLOG_SHA256) { Write-Host 'ERROR: la APK no coincide con el archivo original.'; Write-Host ('Hash recibido: '+$liftlogHash); exit 2 }; Write-Host 'SHA-256 correcto.'; exit 0"
if errorlevel 1 goto bad_hash
echo Comprobando telefono USB...
"%LIFTLOG_ADB%" -d get-state
if errorlevel 1 goto no_device
echo Instalando. Mantenga el telefono conectado...
"%LIFTLOG_ADB%" -d install --no-streaming -r "%LIFTLOG_APK%" > "%LIFTLOG_LOG%" 2>&1
set "LIFTLOG_RESULT=%ERRORLEVEL%"
type "%LIFTLOG_LOG%"
if not "%LIFTLOG_RESULT%"=="0" goto install_failed
echo Abriendo LIFTLOG...
"%LIFTLOG_ADB%" -d shell am start -W -n website.chuma.liftlog/.MainActivity
if errorlevel 1 goto launch_failed
echo Instalacion completada. Compruebe la pantalla del telefono.
echo Puede empezar en modo local. Las cuentas requieren desplegar la API.
pause
exit /b 0
:no_adb
echo ERROR: no se encontro ADB en "%LIFTLOG_ADB%".
goto failed
:no_apk
echo ERROR: extraiga todo el ZIP. La APK debe estar junto a instalar.cmd.
goto failed
:bad_hash
echo No se intento instalar. Descargue y extraiga otra vez el ZIP completo.
goto failed
:no_device
echo Conecte un solo telefono por USB, desbloqueelo y autorice la depuracion USB.
goto failed
:install_failed
echo La instalacion fallo. Copie el contenido de instalacion.log al chat.
goto failed
:launch_failed
echo La instalacion termino, pero no se confirmo la apertura. Copie la salida al chat.
goto failed
:failed
pause
exit /b 1
