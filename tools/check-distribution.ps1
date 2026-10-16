# Validate the public, media-free archive and exercise the frozen builder.
param([string]$DistributionDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $root 'build/VanguardPrincessM.love'))
try {
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match '(^assets/|(^|/)(_conversion|skills)/|(^|/)(data|support-source)\.lton$)') {
            throw "Unexpected distribution entry: $($entry.FullName)"
        }
    }
    if (-not $archive.GetEntry('extensions.txt')) { throw 'Missing EOS extension manifest' }
} finally { $archive.Dispose() }
$out = if ($DistributionDirectory) { $DistributionDirectory } else { Join-Path $root 'dist/VanguardPrincessM' }
foreach ($media in 'assets', 'assets.zip') {
    if (Test-Path -LiteralPath (Join-Path $out $media)) { throw 'Public distribution contains external assets' }
}
$builder = if ($IsWindows) { 'BuildAssets.exe' } else { 'BuildAssets' }
$eosFiles = if ($IsWindows) { @('eos_lhat.dll', 'EOSSDK-Win64-Shipping.dll') }
    elseif ($IsLinux) { @('eos_lhat.so', 'libEOSSDK-Linux-Shipping.so') }
    else { @('eos_lhat.dylib', 'libEOSSDK-Mac-Shipping.dylib') }
foreach ($name in $eosFiles) {
    $file = Join-Path $out "native/$name"
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing EOS distribution file: $name" }
    if ((Get-FileHash -LiteralPath $file).Hash -ne (Get-FileHash -LiteralPath (Join-Path $root "native/$name")).Hash) {
        throw "EOS distribution binary differs from the compiler's copy: $name"
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $out 'eos-ThirdPartySoftwareNotice.txt') -PathType Leaf)) {
    throw 'Missing EOS third-party notice'
}
$programs = @(
    $builder
    if ($IsWindows) { 'VanguardPrincessM.exe' }
    elseif ($IsLinux) { 'VanguardPrincessM', 'lib/liblove-12.0.so' }
    else { 'VanguardPrincessM.command', 'lhat-love.app/Contents/MacOS/love' }
)
foreach ($name in @($programs) + @('ASSETS.md', 'README.md', 'README.ja.md', 'images/buildassets-console.png', 'LICENSE', 'lhat-love-license.txt') + @(if ($IsMacOS) { 'VanguardPrincessM.love' })) {
    if (-not (Test-Path -LiteralPath (Join-Path $out $name) -PathType Leaf)) { throw "Missing distribution file: $name" }
}
if (-not $IsWindows) {
    foreach ($name in $programs | Where-Object { $_ -notlike 'lib/*' }) {
        $mode = [IO.File]::GetUnixFileMode((Join-Path $out $name))
        if (-not ($mode -band [IO.UnixFileMode]::UserExecute)) { throw "Not executable: $name" }
    }
}
if ($IsMacOS) {
    # The bundle must stay as signed; the game is beside it, not inside it.
    & codesign --verify --deep --strict (Join-Path $out 'lhat-love.app')
    if ($LASTEXITCODE -ne 0) { throw 'Engine bundle signature is broken' }
}
$savedPath = $env:PATH
$savedPythonPath = $env:PYTHONPATH
try {
    $env:PATH = if ($IsWindows) { "$env:SystemRoot\System32;$env:SystemRoot" } else { '/usr/bin:/bin' }
    $env:PYTHONPATH = ''
    & (Join-Path $out $builder) --help
    if ($LASTEXITCODE -ne 0) { throw 'Standalone builder failed' }
} finally {
    $env:PATH = $savedPath
    $env:PYTHONPATH = $savedPythonPath
}
Write-Host 'Distribution check passed'
