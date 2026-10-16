# Exercise match completion and rematch through the real game, without EOS servers.
param(
    [string]$Engine = 'C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe',
    [string]$Mock = "$PSScriptRoot/../build/eos/eos_lhat_mock.dll",
    [switch]$RemappedInput,
    [switch]$Spectator,
    [switch]$SpectatorGuest,
    [switch]$Compiled,
    [string]$Vm = 'C:/Users/Owner/source/repos/lhat-love/build-vmonly-shipping/love/Release/lovec.exe'
)
$ErrorActionPreference = 'Stop'
$Spectator = $Spectator -or $SpectatorGuest
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root ('build/online-game/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/native" | Out-Null
Copy-Item -LiteralPath "$root/src" -Destination $stage -Recurse
foreach ($folder in 'data', 'assets') {
    if ($Compiled) {
        if ($folder -eq 'data') { Copy-Item -LiteralPath "$root/$folder" -Destination $stage -Recurse }
    } else {
        New-Item -ItemType Junction -Path "$stage/$folder" -Target "$root/$folder" | Out-Null
    }
}
Copy-Item -LiteralPath $Mock -Destination "$stage/native/eos_lhat.dll"
'native/eos_lhat' | Set-Content "$stage/extensions.txt"
$testIdentity = if ($SpectatorGuest) { 'vanguard-spectator-guest-test' } elseif ($Spectator) { 'vanguard-spectator-host-test' } else { 'vanguard-online-game-test' }
('identity = "' + $testIdentity + '", window = { width = 1280, height = 960 },') | Set-Content "$stage/conf.lton"
'productId = "test", sandboxId = "test", deploymentId = "test", clientId = "test", clientSecret = "test",' | Set-Content "$stage/eosconfig.lton"
Copy-Item -LiteralPath "$root/main.lh" -Destination "$stage/game.lh"
if ($Spectator) {
    $helper = [IO.File]::ReadAllText("$root/tests/select-input.lh").Replace('require^"../main.lh"', 'require^"../game.lh"')
    [IO.File]::WriteAllText("$stage/src/test-select-input.lh", $helper)
}
$testName = if ($Spectator) { "spectator-game" } else { "online-game" }
$marker = if ($Spectator) { "SPECTATOR_GAME_OK" } else { "ONLINE_GAME_OK" }
$entry = [IO.File]::ReadAllText("$root/tests/$testName.lh.in")
if ($RemappedInput) { $entry = $entry.Replace('let^REMAPPED_INPUT = false^', 'let^REMAPPED_INPUT = true^') }
if ($SpectatorGuest) { $entry = $entry.Replace('let^REMOTE_VIEWER = false^', 'let^REMOTE_VIEWER = true^') }
[IO.File]::WriteAllText("$stage/main.lh", $entry)
foreach ($name in 'net', 'online') {
    foreach ($suffix in @('guest', 'third')) {
        $source = [IO.File]::ReadAllText("$root/src/$name.lh").Replace('vp.net', "vp.net$suffix").Replace('vp.online', "vp.online$suffix").Replace('"online.lh"', '"online' + $suffix + '.lh"')
        [IO.File]::WriteAllText("$stage/src/${name}$suffix.lh", $source)
    }
}
if ($Compiled) {
    & $Engine --no-error-screen --compile-game "$stage-compiled" $stage
    if ($LASTEXITCODE -ne 0) { throw 'Online game compilation failed' }
    $stage = "$stage-compiled"
    New-Item -ItemType Junction -Path "$stage/assets" -Target "$root/assets" | Out-Null
    $Engine = $Vm
}
$output = & $Engine --no-error-screen $stage 2>&1 | Tee-Object -FilePath "$stage/result.log"
$code = $LASTEXITCODE
$output | Where-Object { $_ -match "$marker|panic|error|timed out" } | ForEach-Object { Write-Host $_ }
if ($code -ne 0 -or -not ($output -match "^${marker}:")) { throw "Online game test failed ($code). Logs: $stage/result.log" }
