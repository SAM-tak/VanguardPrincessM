# Run the round-start integration test in the compiled, VM-only engine.
# Compile scripts/data only; share the original media through a junction.
param(
    [ValidateSet('replay-round-start', 'replay-round-navigation')]
    [string]$Test = 'replay-round-navigation',
    [string]$Engine = 'C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe',
    [string]$Vm = 'C:/Users/Owner/source/repos/lhat-love/build-vmonly-shipping/love/Release/lovec.exe',
    [string]$Mock = "$PSScriptRoot/../build/eos/eos_lhat_mock.dll"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root ('build/replay-round-start/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/native" | Out-Null
foreach ($folder in 'src', 'data') { Copy-Item -LiteralPath "$root/$folder" -Destination $stage -Recurse }
Copy-Item -LiteralPath $Mock -Destination "$stage/native/eos_lhat.dll"
'native/eos_lhat' | Set-Content "$stage/extensions.txt"
'identity = "vanguard-replay-round-start-test", window = { width = 1280, height = 960 },' | Set-Content "$stage/conf.lton"
$game = [IO.File]::ReadAllText("$root/main.lh").Replace('require^"src/', 'require^"')
[IO.File]::WriteAllText("$stage/src/game.lh", $game)
$helper = [IO.File]::ReadAllText("$root/tests/select-input.lh").Replace('require^"../main.lh"', 'require^"game.lh"')
[IO.File]::WriteAllText("$stage/src/test-select-input.lh", $helper)
$entry = [IO.File]::ReadAllText("$root/tests/$Test.lh").Replace('require^"../main.lh"', 'require^"src/game.lh"').Replace('require^"../tests/select-input.lh"', 'require^"src/test-select-input.lh"').Replace('require^"../src/', 'require^"src/')
[IO.File]::WriteAllText("$stage/main.lh", $entry)
& $Engine --no-error-screen --compile-game "$stage-compiled" $stage
if ($LASTEXITCODE -ne 0) { throw 'Replay round-start test compilation failed' }
New-Item -ItemType Junction -Path "$stage-compiled/assets" -Target "$root/assets" | Out-Null
$output = & $Vm --no-error-screen "$stage-compiled" 2>&1
$code = $LASTEXITCODE
$output | Set-Content "$stage/result.log"
$output | Where-Object { $_ -match '^PASS:|panic|error|mismatch|could not be restored|timeout' } | ForEach-Object { Write-Host $_ }
if ($code -ne 0 -or -not ($output -match '^PASS: (later rounds start independently|Up/Down round jumps)')) {
    throw "Compiled round-start replay failed ($code). Logs: $stage/result.log"
}
