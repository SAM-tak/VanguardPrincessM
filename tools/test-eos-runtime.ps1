# Check real EOS loading with the exact distribution compiler and fused VM.
# No client/account is created and no service connection is attempted.
param(
    [Parameter(Mandatory)][string]$Lovec,
    [Parameter(Mandatory)][string]$ShippingDirectory,
    [string]$NativeDirectory = "$PSScriptRoot/../native"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$Lovec = (Resolve-Path -LiteralPath $Lovec).Path
$ShippingDirectory = (Resolve-Path -LiteralPath $ShippingDirectory).Path
$NativeDirectory = (Resolve-Path -LiteralPath $NativeDirectory).Path
$work = Join-Path $root ('build/eos-runtime-test/' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $work 'source'
$run = Join-Path $work 'run'
New-Item -ItemType Directory -Force "$source/src", "$source/data", $run | Out-Null
Copy-Item -LiteralPath $NativeDirectory -Destination "$source/native" -Recurse
Copy-Item -LiteralPath "$root/extensions.txt" -Destination $source
@'
module^eosruntimetest
import^love.event
import^eos
# Type-check the APIs required by the current lobby without making requests.
let^checkApi = p^client:eos.Client {
    client.setRoom("probe",false^) catch^nil^
    client.kick("") catch^nil^
    let^name = client.displayName() catch^""
    let^room = client.lobby() catch^nil^
    if^room != nil^ { print(room.name,room.locked,name) }
}
public^let^load = p^{
    print(eos.Reliability.reliableOrdered)
    print(eos.EventKind.roomUpdated,eos.EventKind.kicked)
    print("EOS_RUNTIME_OK")
    love.event.quit()
}
'@ | Set-Content -LiteralPath "$source/main.lh" -Encoding utf8
'modules = { window = false^, graphics = false^, audio = false^ },' | Set-Content -LiteralPath "$source/conf.lton"

function Test-Launch([string]$Executable, [string[]]$Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Executable
    $info.WorkingDirectory = $work
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($info)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'EOS runtime test timed out' }
        $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -or -not $output.Contains('EOS_RUNTIME_OK')) {
            throw "EOS load failed ($($process.ExitCode)): $output"
        }
    } finally { $process.Dispose() }
}

Test-Launch $Lovec @('--no-error-screen', $source)
$archive = Join-Path $work 'probe.love'
& "$root/tools/package-game.ps1" -SourceRoot $source -Lovec $Lovec -WorkDirectory "$work/package" -Archive $archive
$launcher = & "$root/tools/fuse-game.ps1" -ShippingDirectory $ShippingDirectory -Archive $archive -OutputDirectory $run -Name eos-probe
Copy-Item -LiteralPath $NativeDirectory -Destination "$run/native" -Recurse
Test-Launch $launcher @('--no-error-screen')
Write-Host 'PASS: bundled EOS loads in the compiler and fused VM-only distribution'
