# Exercise match completion and rematch through the real game, without EOS servers.
param(
    [string]$Engine = 'C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe',
    [string]$Mock = "$PSScriptRoot/../build/eos/eos_lhat_mock.dll"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root ('build/online-game/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/native" | Out-Null
Copy-Item -LiteralPath "$root/src" -Destination $stage -Recurse
foreach ($folder in 'data', 'assets') {
    New-Item -ItemType Junction -Path "$stage/$folder" -Target "$root/$folder" | Out-Null
}
Copy-Item -LiteralPath $Mock -Destination "$stage/native/eos_lhat.dll"
'native/eos_lhat' | Set-Content "$stage/extensions.txt"
'identity = "vanguard-online-game-test", window = { width = 1280, height = 960 },' | Set-Content "$stage/conf.lton"
'productId = "test", sandboxId = "test", deploymentId = "test", clientId = "test", clientSecret = "test",' | Set-Content "$stage/eosconfig.lton"
Copy-Item -LiteralPath "$root/main.lh" -Destination "$stage/game.lh"
Copy-Item -LiteralPath "$root/tests/online-game.lh.in" -Destination "$stage/main.lh"
foreach ($name in 'net', 'online') {
    $source = [IO.File]::ReadAllText("$root/src/$name.lh").Replace('vp.net', 'vp.netguest').Replace('vp.online', 'vp.onlineguest').Replace('"online.lh"', '"onlineguest.lh"')
    [IO.File]::WriteAllText("$stage/src/${name}guest.lh", $source)
}
$output = & $Engine --no-error-screen $stage 2>&1
$code = $LASTEXITCODE
$output | Set-Content "$stage/result.log"
$output | Where-Object { $_ -match 'ONLINE_GAME_OK|panic|error|timed out' } | ForEach-Object { Write-Host $_ }
if ($code -ne 0 -or -not ($output -match '^ONLINE_GAME_OK:')) { throw "Online game test failed ($code). Logs: $stage/result.log" }
