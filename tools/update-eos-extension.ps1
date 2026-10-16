# Replace all bundled extensions together after publishing eos-lhat.
# SDK runtimes and notices remain the matching, separately supplied SDK files.
param([Parameter(Mandatory)][string]$Tag)
$ErrorActionPreference = 'Stop'
if ($Tag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:[-.][A-Za-z0-9.-]+)?$') { throw 'Specify an eos-lhat release tag, for example v0.1.4' }
$root = Split-Path $PSScriptRoot -Parent
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/SAM-tak/eos-lhat/releases/tags/$Tag"
$targets = [ordered]@{
    'eos_lhat.dll' = 'windows-x64'
    'eos_lhat.so' = 'linux-x64'
    'eos_lhat.dylib' = 'maxos-universal'
}
$work = Join-Path $root ('build/eos-update/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $work | Out-Null
$checksums = [ordered]@{}
foreach ($name in $targets.Keys) {
    $asset = @($release.assets | Where-Object name -CEQ $name)
    if ($asset.Count -ne 1 -or $asset[0].digest -cnotmatch '^sha256:[0-9a-f]{64}$') {
        throw "Release must contain $name with a SHA256 digest"
    }
    $file = Join-Path $work $name
    Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile $file
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ("sha256:$hash" -cne $asset[0].digest) { throw "SHA256 mismatch: $name" }
    $checksums[$name] = $hash
}
# Verify every download before changing any tracked file.
foreach ($name in $targets.Keys) {
    Copy-Item -LiteralPath (Join-Path $work $name) -Destination (Join-Path $root "extensions/eos/$($targets[$name])/$name") -Force
}
$record = [ordered]@{ repository = 'SAM-tak/eos-lhat'; tag = $Tag; sha256 = $checksums }
$json = ConvertTo-Json -InputObject $record -Depth 4
[IO.File]::WriteAllText((Join-Path $root 'tools/eos-release.json'), $json + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "Updated all bundled EOS extensions to $Tag. Run setup-eos.ps1 and test-eos-runtime.ps1 before committing."
