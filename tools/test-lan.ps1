# Runs tests/lan-vs.lh as two processes on this machine, a host and a guest,
# and checks that both recorded the same match (TechnicalDocuments/0157).
param([string]$Engine = "C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe",
      [int]$TimeoutSeconds = 300,
      [switch]$Impaired,
      [switch]$Realtime,
      [ValidateRange(-1, 2147483647)][int]$Seed = -1,
      [ValidateRange(0, 7)][int]$Stage = 0)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = [IO.File]::ReadAllText((Join-Path $root 'tests/lan-vs.lh')).Replace('require^"../', 'require^"')
if ($Impaired) { $source = $source.Replace('let^IMPAIRED = false^', 'let^IMPAIRED = true^') }
if ($Realtime) { $source = $source.Replace('let^REALTIME = false^', 'let^REALTIME = true^') }
$source = $source.Replace('let^STAGE = 0', "let^STAGE = $Stage")
$source = $source.Replace('let^SEED = -1', "let^SEED = $Seed")
$roles = @('host', 'guest')
$entries = @{}
$logs = @{}
foreach ($role in $roles) {
    $entry = Join-Path $root ".lan-$role-test.lh"
    if (Test-Path -LiteralPath $entry) { throw "Test entry already exists: $entry" }
    $text = $source.Replace('let^ROLE = "host"', "let^ROLE = `"$role`"")
    [IO.File]::WriteAllText($entry, $text)
    $entries[$role] = $entry
    $logs[$role] = Join-Path ([IO.Path]::GetTempPath()) "vp-lan-$role-$PID.log"
}
$processes = @{}
try {
    foreach ($role in $roles) {
        $processes[$role] = Start-Process -FilePath $Engine -ArgumentList '--no-error-screen', ".lan-$role-test.lh" `
            -WorkingDirectory $root -RedirectStandardOutput $logs[$role] -RedirectStandardError "$($logs[$role]).err" -PassThru -WindowStyle Hidden
        if ($role -eq 'host') { Start-Sleep -Seconds 2 }
    }
    foreach ($role in $roles) {
        if (-not $processes[$role].WaitForExit($TimeoutSeconds * 1000)) {
            $processes[$role].Kill()
            Write-Host "$role timed out"
        }
    }
} finally {
    foreach ($role in $roles) { Remove-Item -LiteralPath $entries[$role] -ErrorAction SilentlyContinue }
}
$results = @{}
$failed = $false
foreach ($role in $roles) {
    $out = @()
    if (Test-Path $logs[$role]) { $out += Get-Content $logs[$role] }
    if (Test-Path "$($logs[$role]).err") { $out += Get-Content "$($logs[$role]).err" }
    $out | Where-Object { $_ -match '^\[|^RESULT|^Replay ended|panic|error|DESYNC|LAN:' } | ForEach-Object { Write-Host "$role> $_" }
    $code = $processes[$role].ExitCode
    $result = $out | Where-Object { $_ -match '^RESULT' } | Select-Object -Last 1
    $results[$role] = $result
    if ($code -ne 0 -or -not $result) { $failed = $true; Write-Host "$role failed (exit $code)" }
    if ($code -eq 0 -and $result) {
        Remove-Item -LiteralPath $logs[$role], "$($logs[$role]).err" -ErrorAction SilentlyContinue
    } else { Write-Host "Logs kept: $($logs[$role])" }
}
if (-not $failed -and $results['host'] -ne $results['guest']) {
    $failed = $true
    Write-Host "The two sides recorded different matches:`n  host:  $($results['host'])`n  guest: $($results['guest'])"
}
if ($failed) { exit 1 }
Write-Host "PASS: host and guest played one match over the LAN link and recorded it alike: $($results['host'])"
exit 0
