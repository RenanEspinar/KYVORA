# Ejecutar desde PowerShell en esta carpeta: .\subir-github.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
foreach ($cmd in @('git', 'gh')) { if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Falta $cmd. Instala Git y GitHub CLI (gh) antes de continuar." } }
& gh auth status
if ($LASTEXITCODE -ne 0) { & gh auth login; if ($LASTEXITCODE -ne 0) { throw 'No se inicio sesion en GitHub.' } }
if (-not (Test-Path '.git')) { & git init -b main; if ($LASTEXITCODE -ne 0) { throw 'git init fallo' } }
& git add .
if ($LASTEXITCODE -ne 0) { throw 'git add fallo' }
& git add -f 'releases/LIFTLOG-1.0-pruebas.apk'
if ($LASTEXITCODE -ne 0) { throw 'No se pudo agregar la APK' }
& git commit -m 'LIFTLOG 1.0 - fuentes y APK de pruebas'
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el commit (comprueba git config user.name y user.email)' }
& gh repo create 'LIFTLOG' --private --source . --remote origin --push
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear o subir el repositorio. Si ya existe, usa git remote add origin y git push.' }
Write-Host 'Listo: repositorio privado LIFTLOG publicado en GitHub' -ForegroundColor Green
