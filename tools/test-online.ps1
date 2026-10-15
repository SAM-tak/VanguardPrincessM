param(
    [string]$Engine = 'C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe',
    [string]$Vm = 'C:/Users/Owner/source/repos/lhat-love/build-vmonly-shipping/love/Release/lovec.exe',
    [string]$Mock = "$PSScriptRoot/../build/eos/eos_lhat_mock.dll"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath $Mock -PathType Leaf)) { throw 'Build eos-lhat with BUILD_TESTING=ON and pass -Mock <library>' }
$stage = Join-Path $root ('build/online-test/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/src", "$stage/native" | Out-Null
Copy-Item -LiteralPath $Mock -Destination "$stage/native/eos_lhat.dll"
'native/eos_lhat' | Set-Content -LiteralPath "$stage/extensions.txt" -Encoding utf8
'identity = "vanguard-online-test", window = false^, modules = { graphics = false^, audio = false^ },' | Set-Content -LiteralPath "$stage/conf.lton" -Encoding utf8
Copy-Item -LiteralPath "$root/tests/online-link.lh.in" -Destination "$stage/main.lh"
foreach ($name in 'net', 'online') {
    $source = [IO.File]::ReadAllText("$root/src/$name.lh")
    [IO.File]::WriteAllText("$stage/src/$name.lh", $source)
    foreach ($suffix in 'guest', 'third', 'fourth', 'fifth') {
        $copy = $source.Replace('vp.net', "vp.net$suffix").Replace('vp.online', "vp.online$suffix").Replace('"online.lh"', '"online' + $suffix + '.lh"')
        [IO.File]::WriteAllText("$stage/src/$name$suffix.lh", $copy)
    }
}
foreach ($name in 'lanmenu', 'roommenu', 'lobby', 'locale', 'settings') {
    Copy-Item -LiteralPath "$root/src/$name.lh" -Destination "$stage/src/$name.lh"
}
'productId = "test", sandboxId = "test", deploymentId = "test", clientId = "test", clientSecret = "test",' |
    Set-Content -LiteralPath "$stage/eosconfig.lton" -Encoding utf8
$output = & $Engine --no-error-screen $stage 2>&1
$output | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0 -or -not ($output -match '^ONLINE_LINK_OK:')) { throw "Online test failed ($LASTEXITCODE). Stage: $stage" }
& $Engine --no-error-screen --compile-game "$stage-compiled" $stage
if ($LASTEXITCODE -ne 0) { throw "Online test compilation failed ($LASTEXITCODE)" }
$output = & $Vm --no-error-screen "$stage-compiled" 2>&1
$output | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0 -or -not ($output -match '^ONLINE_LINK_OK:')) { throw "Compiled online test failed ($LASTEXITCODE). Stage: $stage-compiled" }
