param(
    [string]$Engine = 'C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe',
    [string]$Vm = 'C:/Users/Owner/source/repos/lhat-love/build-vmonly-shipping/love/Release/lovec.exe'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root ('build/input-test/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/src" | Out-Null
Copy-Item -LiteralPath "$root/tests/input-config.lh.in" -Destination "$stage/main.lh"
foreach ($name in 'input', 'settings', 'keynames') {
    Copy-Item -LiteralPath "$root/src/$name.lh" -Destination "$stage/src/$name.lh"
}
'identity = "vanguard-input-test", window = false^, modules = {graphics = false^, audio = false^},' |
    Set-Content -LiteralPath "$stage/conf.lton" -Encoding utf8
$output = & $Engine --no-error-screen $stage 2>&1
$output | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0 -or -not ($output -match '^INPUT_CONFIG_OK:')) { throw "Input test failed. Stage: $stage" }
& $Engine --no-error-screen --compile-game "$stage-compiled" $stage
if ($LASTEXITCODE -ne 0) { throw 'Input test compilation failed' }
$output = & $Vm --no-error-screen "$stage-compiled" 2>&1
$output | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0 -or -not ($output -match '^INPUT_CONFIG_OK:')) { throw "Compiled input test failed. Stage: $stage-compiled" }
