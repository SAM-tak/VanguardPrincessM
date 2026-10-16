param([string]$Engine = "C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe",
      [ValidateSet('async-flow', 'story-flow', 'story-navigation', 'story-continue', 'support-flow', 'support-palettes', 'selective-preload', 'victory-preload', 'attract-flow', 'combat-flow', 'combo-correction', 'match-intro', 'memory-soak', 'metadata-lifetime', 'vs-memory-return', 'story-memory-return', 'sound-reuse', 'turn-result', 'hilda-whiteout', 'ending-chain', 'load-throughput', 'system-object-position', 'locale-image', 'practice-mode', 'practice-guard', 'locale-system', 'locale-reload', 'f8-main-reload', 'select-stages', 'settings-create', 'replay-list', 'gauge-random', 'replay-roundtrip', 'replay-round-start', 'replay-round-navigation', 'stage-round-start', 'replay-format', 'spectator-stream', 'costate-probe', 'snapshot-replay', 'replay-controls', 'hold-fastpath', 'events', 'vm-audit')][string]$Test = 'async-flow')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$entry = Join-Path $root '.async-flow-test.lh'
if (Test-Path -LiteralPath $entry) { throw "Test entry already exists: $entry" }
# The test lives under tests/, but LOVE must mount the game root for assets.
$source = [IO.File]::ReadAllText((Join-Path $root "tests/$Test.lh"))
if ($Test -eq 'f8-main-reload') {
    # Run the actual game body as the engine's main unit, rather than require
    # it from a test entry (which would preserve vp.main across reload).
    $game = [IO.File]::ReadAllText((Join-Path $root 'main.lh'))
    foreach ($callback in @('load', 'update', 'draw')) {
        $game = $game.Replace("public^let^$callback =", "let^game_$callback =")
        $source = $source.Replace("vp.main.$callback(", "game_$callback(")
    }
    # Keep the source a valid standalone module for language-server analysis;
    # only the executable harness is merged into vp.main for this test.
    $source = $source -replace '(?m)^module\^vp\.f8mainreloadtest\r?\n', ''
    $source = $source -replace '(?m)^import\^love\.(event|keyboard|timer)\r?\n', ''
    $source = $source -replace '(?m)^require\^"\.\./(main\.lh|src/(arena|resource)\.lh)"\r?\n', ''
    $source = $source.Replace('vp.main.status(', 'status(').Replace('vp.main.keypressed(', 'keypressed(')
    $source = $game + "`n" + $source
}
[IO.File]::WriteAllText($entry, $source.Replace('require^"../', 'require^"'))
try {
    Push-Location $root
    & $Engine --no-error-screen $entry
    $result = $LASTEXITCODE
    Write-Host "lovec exit code: $result"
} finally {
    Pop-Location
    Remove-Item -LiteralPath $entry
}
exit $result
