# Install an ABI-compatible extension and its matching SDK runtime locally.
param(
    [string]$Extension = "$PSScriptRoot/../build/eos/eos_lhat.dll",
    [string]$Runtime = "$PSScriptRoot/../build/eos/EOSSDK-Win64-Shipping.dll"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
foreach ($file in $Extension, $Runtime) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing EOS dependency: $file" }
}
$native = Join-Path $root 'native'
New-Item -ItemType Directory -Force $native | Out-Null
Copy-Item -LiteralPath $Extension, $Runtime -Destination $native -Force
Write-Host 'EOS installed in native/. The extension must match the engine ABI.'
