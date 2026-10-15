# Build-time configuration only. Read secrets from the environment, never argv.
param([string]$OutputFile = "$PSScriptRoot/../eosconfig.lton")
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputFile) { throw 'EOS config already exists; refusing to overwrite it' }
$fields = [ordered]@{
    productId = 'EOS_PRODUCT_ID'
    sandboxId = 'EOS_SANDBOX_ID'
    deploymentId = 'EOS_DEPLOYMENT_ID'
    clientId = 'EOS_CLIENT_ID'
    clientSecret = 'EOS_CLIENT_SECRET'
}
$lines = foreach ($field in $fields.GetEnumerator()) {
    $value = [Environment]::GetEnvironmentVariable($field.Value)
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Missing repository secret: $($field.Value)" }
    # LTON quoted strings use these escapes. Avoid interpolating values as code.
    $escaped = $value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t')
    if ($escaped -match '[\x00-\x1f]') { throw "Unsupported control character in $($field.Value)" }
    $field.Key + ' = "' + $escaped + '",'
}
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputFile), ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
