# Install the platform's bundled extension and matching SDK runtime.
# Explicit paths can override the bundle for local engine development.
param(
    [string]$Extension,
    [string]$Runtime,
    [string]$Platform,
    [string]$Destination = "$PSScriptRoot/../native"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'engine-platform.ps1')
if (-not $Platform) { $Platform = Get-EnginePlatform }
$bundle = switch ($Platform) {
    'windows-x64' { @('windows-x64', 'eos_lhat.dll', 'EOSSDK-Win64-Shipping.dll') }
    'linux-x64' { @('linux-x64', 'eos_lhat.so', 'libEOSSDK-Linux-Shipping.so') }
    # The tracked universal bundle's directory is spelled "maxos".
    { $_ -in 'macos-arm64', 'macos-x64' } { @('maxos-universal', 'eos_lhat.dylib', 'libEOSSDK-Mac-Shipping.dylib') }
    default { throw "Unsupported EOS platform: $Platform" }
}
if ([bool]$Extension -ne [bool]$Runtime) { throw 'Specify both -Extension and -Runtime, or neither' }
if (-not $Extension) {
    $Extension = Join-Path $root "extensions/eos/$($bundle[0])/$($bundle[1])"
    $Runtime = Join-Path $root "extensions/eos/$($bundle[0])/$($bundle[2])"
}
foreach ($file in $Extension, $Runtime) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing EOS dependency: $file" }
}
New-Item -ItemType Directory -Force $Destination | Out-Null
Copy-Item -LiteralPath $Extension, $Runtime -Destination $Destination -Force
Write-Host "EOS installed for $Platform. The extension must match the engine ABI."
