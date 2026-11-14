$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'KYVORA-2.2'
$desktop = [Environment]::GetFolderPath('Desktop')
$repo = Join-Path $desktop 'LIFTLOG-1.1-publicacion\repositorio'

if (!(Test-Path -LiteralPath $source)) { throw 'No se encuentra KYVORA-2.2 junto a este script.' }
if (!(Test-Path -LiteralPath (Join-Path $repo '.git'))) {
    throw "No se encuentra el repositorio: $repo"
}
$dirty = @(& git -C $repo status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'No se puede consultar el estado Git.' }
if (@($dirty | Where-Object { $_ -ne '' }).Count -gt 0) {
    throw 'Hay archivos sin guardar en Git. Guarda o respalda los cambios antes de aplicar el parche.'
}

& git -C $repo pull --ff-only origin main
if ($LASTEXITCODE -ne 0) { throw 'No se pudo actualizar main.' }

$files = @()
Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($source.Length + 1)
    if ($relative -match '(^|[\\/])(__pycache__|\.pytest_cache)([\\/]|$)' -or $relative.EndsWith('.pyc')) { return }
    $target = Join-Path $repo $relative
    New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    $files += $relative.Replace('\', '/')
}

& git -C $repo diff --check
if ($LASTEXITCODE -ne 0) { throw 'Hay errores de espacios o conflictos en los archivos.' }
& git -C $repo add -- $files
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron añadir los archivos.' }
& git -C $repo diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host 'KYVORA 2.2 ya estaba aplicado; no hay cambios nuevos.' -ForegroundColor Yellow
    exit 0
}
& git -C $repo commit -m 'KYVORA 2.2 - Métodos avanzados y superseries explicadas'
if ($LASTEXITCODE -ne 0) { throw 'Error creando el commit.' }
& git -C $repo push origin main
if ($LASTEXITCODE -ne 0) { throw 'Error publicando en GitHub.' }
Write-Host 'KYVORA 2.2 PUBLICADO. Comprueba GitHub Actions y luego actualiza el backend antes de sincronizar métodos avanzados.' -ForegroundColor Green
