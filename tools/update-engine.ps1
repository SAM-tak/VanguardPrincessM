# Pin engine-release.json to another lhat-love release: every platform's
# compiler and runtime asset, with the SHA-256 digests GitHub publishes for
# them. Needs the gh CLI. Without -Tag, the newest release (prereleases
# included) is used. -Verify then downloads this platform's pair and checks it.
param(
    [string]$Tag,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot 'engine-release.json'
$release = Get-Content -Raw $path | ConvertFrom-Json
$repository = $release.repository
if (-not $Tag) {
    $Tag = gh release list -R $repository --limit 1 --json tagName -q '.[0].tagName'
    if ($LASTEXITCODE -ne 0 -or -not $Tag) { throw "Could not find the latest release of $repository" }
}
$json = gh release view $Tag -R $repository --json assets
if ($LASTEXITCODE -ne 0) { throw "No release $Tag in $repository" }
$digests = @{}
foreach ($a in ($json | ConvertFrom-Json).assets) {
    if ($a.digest -notmatch '^sha256:([0-9a-f]{64})$') { throw "No SHA-256 digest for $($a.name)" }
    $digests[$a.name] = $Matches[1]
}
$old = $release.tag
foreach ($platform in $release.platforms.PSObject.Properties) {
    foreach ($kind in $platform.Value.PSObject.Properties) {
        $name = $kind.Value.asset.Replace($old, $Tag)
        if (-not $digests.ContainsKey($name)) { throw "$Tag has no $name ($($platform.Name) $($kind.Name))" }
        $kind.Value.asset = $name
        $kind.Value.sha256 = $digests[$name]
    }
}
$release.tag = $Tag
[IO.File]::WriteAllText($path, ($release | ConvertTo-Json -Depth 10).ReplaceLineEndings("`n") + "`n")
Write-Host "engine-release.json: $old -> $Tag"
if ($Verify) {
    $destination = Join-Path ([IO.Path]::GetTempPath()) "lhat-love-$Tag-$([Guid]::NewGuid().ToString('N'))"
    try {
        & (Join-Path $PSScriptRoot 'download-engine.ps1') -Destination $destination
        Write-Host "Verified the $Tag assets for this platform"
    } finally {
        Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
    }
}
