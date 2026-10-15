# Windows Account Portal login requires the EOS bootstrapper and EOS Service.
param(
    [string]$Engine = 'C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe',
    [string]$BootstrapperTool = 'C:/Users/Owner/source/repos/eos-lhat/EOSSDK/SDK/Tools/EOSBootstrapperTool.exe',
    [switch]$PrepareOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
foreach ($file in $Engine, $BootstrapperTool) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing: $file" }
}
$folder = Join-Path $root 'build/eos-launcher'
New-Item -ItemType Directory -Force $folder | Out-Null
$launcher = Join-Path $folder 'VanguardPrincessOnline.exe'
$runtime = Join-Path $folder 'engine'
New-Item -ItemType Directory -Force $runtime | Out-Null
Copy-Item -LiteralPath $Engine -Destination $runtime -Force
Get-ChildItem -LiteralPath (Split-Path $Engine -Parent) -Filter '*.dll' | Copy-Item -Destination $runtime -Force
# The tool requires a relative executable path, including across drive letters.
& $BootstrapperTool --output-path $launcher --app-path ('engine/' + (Split-Path $Engine -Leaf)) --working-dir '.'
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $launcher)) { throw 'Could not prepare the EOS bootstrapper. Run from a console terminal.' }
if (-not $PrepareOnly) { & $launcher --no-error-screen $root }
