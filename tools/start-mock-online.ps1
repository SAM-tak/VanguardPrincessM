# Launch independent local users, without Epic accounts or EOS services.
param(
    [ValidateRange(3, 16)][int]$Players = 3,
    [string]$Engine = 'C:/Users/Owner/source/repos/lhat-love/build/love/Release/love.exe',
    [string]$Python = 'python',
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$Engine = (Resolve-Path -LiteralPath $Engine).Path
$pythonCommand = (Get-Command $Python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
# Resolve Windows App Execution Aliases / py.exe to the actual interpreter,
# so the owned broker PID is also the process stopped in finally.
$pythonExe = & $pythonCommand -c 'import sys; print(sys.executable)'
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) { throw 'Python 3.9 or later is required.' }
if ($Check) { $Players = 4 }
if (-not $Check -and -not (Test-Path -LiteralPath "$root/assets" -PathType Container)) { throw 'Build the game assets before launching.' }
$sessionId = [guid]::NewGuid().ToString('N')
$session = Join-Path $root "build/mock-online/$sessionId"
New-Item -ItemType Directory -Force $session | Out-Null
$broker = $null
$games = @()
$identities = @()
$titles = @()
$placed = @{}
if (-not $Check -and -not ('VanguardMockWindows' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class VanguardMockWindows {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string className, string title);
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr window, int x, int y, int width, int height, bool repaint);
}
'@
}
try {
    $readyPath = Join-Path $session 'broker.json'
    $brokerScript = Join-Path $PSScriptRoot 'mock-online/broker.py'
    $broker = Start-Process -FilePath $pythonExe -ArgumentList @(('"' + $brokerScript + '"'), '--ready-file', ('"' + $readyPath + '"')) -PassThru -WindowStyle Hidden -RedirectStandardOutput "$session/broker.log" -RedirectStandardError "$session/broker-error.log"
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath $readyPath)) {
        if ($broker.HasExited) { throw "Local broker failed. See $session/broker-error.log" }
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Local broker startup timed out.' }
        Start-Sleep -Milliseconds 100
    }
    $endpoint = Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
    for ($i = 1; $i -le $Players; $i++) {
        $folder = Join-Path $session "player$i"
        New-Item -ItemType Directory -Force $folder | Out-Null
        Copy-Item -LiteralPath "$root/src" -Destination $folder -Recurse
        $source = [IO.File]::ReadAllText("$folder/src/online.lh").Replace('import^eos', 'require^"mock-eos.lh"')
        [IO.File]::WriteAllText("$folder/src/online.lh", $source)
        Copy-Item -LiteralPath "$PSScriptRoot/mock-online/eos.lh" -Destination "$folder/src/mock-eos.lh"
        # No native EOS extension or real credentials are loaded in this stage.
        [IO.File]::WriteAllText("$folder/extensions.txt", '')
        [IO.File]::WriteAllText("$folder/eosconfig.lton", 'productId="local",sandboxId="local",deploymentId="local",clientId="local",clientSecret="local",')
        @{ port = $endpoint.port; token = $endpoint.token; player = "local-player-$i" } | ConvertTo-Json | Set-Content -LiteralPath "$folder/mock-online.json" -Encoding utf8
        $identity = "vanguard-mock-$sessionId-$i"
        $identities += $identity
        if ($Check) {
            $config = 'identity="' + $identity + '",window=false^,modules={graphics=false^,audio=false^},'
            $entry = [IO.File]::ReadAllText("$PSScriptRoot/mock-online/check.lh")
        } else {
            foreach ($name in 'data', 'assets') {
                New-Item -ItemType Junction -Path "$folder/$name" -Target "$root/$name" | Out-Null
            }
            Copy-Item -LiteralPath "$root/main.lh" -Destination "$folder/game.lh"
            $title = "Vanguard Princess M - LOCAL $i ($($sessionId.Substring(0, 6)))"
            $titles += $title
            $config = 'identity="' + $identity + '",window={title="' + $title + '",width=640,height=480},'
            $entry = [IO.File]::ReadAllText("$PSScriptRoot/mock-online/main.lh")
        }
        [IO.File]::WriteAllText("$folder/conf.lton", $config)
        [IO.File]::WriteAllText("$folder/main.lh", $entry.Replace('__PLAYER__', [string]$i))
        $style = if ($Check) { 'Hidden' } else { 'Normal' }
        $games += Start-Process -FilePath $Engine -ArgumentList @('--no-error-screen', ('"' + $folder + '"')) -WorkingDirectory $folder -WindowStyle $style -PassThru -RedirectStandardOutput "$folder/output.log" -RedirectStandardError "$folder/error.log"
    }
    Write-Host "Local mock users: $Players. Logs: $session"
    if ($Check) {
        $deadline = [DateTime]::UtcNow.AddSeconds(45)
        while ($true) {
            $passed = 0
            foreach ($identity in $identities) {
                if ((Test-Path -LiteralPath "$env:APPDATA/LOVE/$identity/mock-check.ok") -or (Test-Path -LiteralPath "$env:APPDATA/$identity/mock-check.ok")) { $passed++ }
            }
            if ($passed -eq $Players) { Write-Host 'MOCK_LAUNCHER_OK: four independent processes, room admission, battle inputs, host observation and late guest observation'; break }
            if (($games | Where-Object HasExited) -or $broker.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw "Local launcher check failed ($passed/$Players). See $session/player*/error.log and output.log" }
            Start-Sleep -Milliseconds 100
        }
    } else {
        Write-Host 'LOCAL 1: create a room. Other windows: search and join it.'
        Write-Host 'Seat two players at a table and make both READY. Select that table in another window to spectate.'
        Write-Host 'F3 on each fighter window enables its CPU. Close all game windows to stop the local broker.'
        while ($games | Where-Object { -not $_.HasExited }) {
            if ($broker.HasExited) { throw "Local broker stopped. See $session/broker-error.log" }
            foreach ($game in $games) { if ($game.HasExited -and $game.ExitCode -ne 0) { throw "A game instance failed. See $session/player*/error.log and output.log" } }
            for ($i = 0; $i -lt [Math]::Min(4, $Players); $i++) {
                if ($placed[$i]) { continue }
                $handle = [VanguardMockWindows]::FindWindow($null, $titles[$i])
                if ($handle -ne [IntPtr]::Zero) {
                    $null = [VanguardMockWindows]::MoveWindow($handle, 20 + ($i % 2) * 660, 20 + [int][Math]::Floor($i / 2) * 520, 656, 519, $true)
                    $placed[$i] = $true
                }
            }
            Start-Sleep -Milliseconds 250
        }
        foreach ($game in $games) { if ($game.ExitCode -ne 0) { throw "A game instance failed. See $session/player*/error.log and output.log" } }
    }
} finally {
    foreach ($game in $games) { if (-not $game.HasExited) { Stop-Process -Id $game.Id -ErrorAction SilentlyContinue } }
    if ($broker -and -not $broker.HasExited) { Stop-Process -Id $broker.Id -ErrorAction SilentlyContinue }
}
