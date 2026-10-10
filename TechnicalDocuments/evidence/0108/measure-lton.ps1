$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$source = Join-Path $root 'stage'
$compiler = 'C:\Users\Owner\source\repos\lhat-love\build\love\Release\lovec.exe'
$work = Join-Path $root ('lton-timing-' + [guid]::NewGuid().ToString('N'))
$files = @(Get-ChildItem -LiteralPath $source -Recurse -Filter *.lton | Sort-Object Length -Descending)
$results = @()
foreach ($jobs in 1, 6) {
    $buckets = @(for ($i = 0; $i -lt $jobs; $i++) {
        $inputDir = Join-Path $work "$jobs/source-$i"
        New-Item -ItemType Directory -Path $inputDir -Force | Out-Null
        'module^benchmark' | Set-Content -LiteralPath (Join-Path $inputDir 'main.lh') -Encoding utf8
        [pscustomobject]@{ Input = $inputDir; Output = (Join-Path $work "$jobs/output-$i"); Bytes = 0L }
    })
    foreach ($file in $files) {
        $bucket = $buckets | Sort-Object Bytes | Select-Object -First 1
        $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
        $target = Join-Path $bucket.Input $relative
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
        $bucket.Bytes += $file.Length
    }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $running = @()
    try {
        foreach ($bucket in $buckets) {
            $info = [Diagnostics.ProcessStartInfo]::new()
            $info.FileName = $compiler
            $info.UseShellExecute = $false
            $info.CreateNoWindow = $true
            $info.WindowStyle = 'Hidden'
            $info.RedirectStandardOutput = $true
            $info.RedirectStandardError = $true
            foreach ($arg in @('--no-error-screen', '--compile-game', $bucket.Output, $bucket.Input)) {
                $info.ArgumentList.Add($arg)
            }
            $p = [Diagnostics.Process]::Start($info)
            $running += [pscustomobject]@{ Process = $p; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync() }
        }
        foreach ($run in $running) {
            if (-not $run.Process.WaitForExit(120000)) { throw 'Compiler timed out' }
            $stdout = $run.Out.GetAwaiter().GetResult()
            $stderr = $run.Err.GetAwaiter().GetResult()
            if ($run.Process.ExitCode -ne 0) { throw "$stdout`n$stderr" }
        }
        $seconds = $timer.Elapsed.TotalSeconds
        $results += [pscustomobject]@{ Jobs = $jobs; Seconds = $seconds }
        Write-Host "$jobs workers: $seconds seconds"
    } finally {
        foreach ($run in $running) {
            if (-not $run.Process.HasExited) { $run.Process.Kill($true); $run.Process.WaitForExit() }
            $run.Process.Dispose()
        }
    }
}
$mismatches = @()
foreach ($bucket in $buckets) {
    foreach ($file in Get-ChildItem -LiteralPath $bucket.Output -Recurse -Filter *.lton) {
        $relative = [IO.Path]::GetRelativePath($bucket.Output, $file.FullName)
        $baseline = Join-Path $work "1/output-0/$relative"
        if ((Get-FileHash -LiteralPath $baseline).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) {
            $mismatches += $relative
        }
    }
}
[pscustomobject]@{ Work = $work; Files = $files.Count; Timings = $results; Mismatches = $mismatches } |
    ConvertTo-Json -Depth 5 | Tee-Object -FilePath (Join-Path $work 'results.json')
