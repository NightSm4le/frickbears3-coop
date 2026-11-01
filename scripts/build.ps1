param(
    [Parameter(Mandatory = $true)]
    [string]$BaseData,
    [Parameter(Mandatory = $true)]
    [string]$UndertaleModCli,
    [string]$OutputPath = "",
    [switch]$Force,
    [switch]$AdminCheats
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$base = (Resolve-Path -LiteralPath $BaseData).Path
$cli = (Resolve-Path -LiteralPath $UndertaleModCli).Path

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $fileName = if ($AdminCheats) { "data_coop_v215_admin.win" } else { "data_coop_v215.win" }
    $OutputPath = Join-Path $repo "build\$fileName"
}
$output = [IO.Path]::GetFullPath($OutputPath)
if ([StringComparer]::OrdinalIgnoreCase.Equals($base, $output)) {
    throw "OutputPath must not overwrite the original data.win."
}
if ((Test-Path -LiteralPath $output) -and -not $Force) {
    throw "Output already exists: $output. Choose another path or pass -Force."
}

$outDir = Split-Path -Parent $output
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$buildLog = "$output.build.log"
$verifyLog = "$output.verify.log"
$temp = Join-Path $outDir ([IO.Path]::GetFileNameWithoutExtension($output) + "." + [Guid]::NewGuid().ToString("N") + ".building.win")
$oldModDir = $env:COOP_MOD_DIR
$oldStage = $env:COOP_STAGE
$oldCheats = $env:COOP_CHEATS

try {
    $env:COOP_MOD_DIR = $repo
    $env:COOP_STAGE = "full"
    $env:COOP_CHEATS = if ($AdminCheats) { "1" } else { "0" }
    & $cli load $base -s (Join-Path $repo "scripts\apply.csx") -o $temp -f *> $buildLog
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temp)) {
        throw "Mod build failed; see $buildLog"
    }

    $verification = & $cli load $temp -s (Join-Path $repo "tests\verify.csx") 2>&1
    $verifyExit = $LASTEXITCODE
    $verifyText = ($verification | Out-String)
    Set-Content -LiteralPath $verifyLog -Value $verifyText -Encoding UTF8
    $expectedVerify = if ($AdminCheats) { "VERIFY OK full-admin" } else { "VERIFY OK full" }
    if ($verifyExit -ne 0 -or $verifyText -notmatch [regex]::Escape($expectedVerify)) {
        throw "Static verification failed; see $verifyLog"
    }

    if (Test-Path -LiteralPath $output) {
        $backup = "$output.previous"
        if (Test-Path -LiteralPath $backup) {
            throw "Cannot preserve existing output because its backup already exists: $backup"
        }
        Move-Item -LiteralPath $output -Destination $backup
    }
    Move-Item -LiteralPath $temp -Destination $output
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Output $expectedVerify
    Write-Output "Built $output"
    Write-Output "SHA256 $hash"
    Write-Output "Build log $buildLog"
    Write-Output "Verify log $verifyLog"
}
finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Force
    }
    if ($null -eq $oldModDir) { Remove-Item Env:COOP_MOD_DIR -ErrorAction SilentlyContinue }
    else { $env:COOP_MOD_DIR = $oldModDir }
    if ($null -eq $oldStage) { Remove-Item Env:COOP_STAGE -ErrorAction SilentlyContinue }
    else { $env:COOP_STAGE = $oldStage }
    if ($null -eq $oldCheats) { Remove-Item Env:COOP_CHEATS -ErrorAction SilentlyContinue }
    else { $env:COOP_CHEATS = $oldCheats }
}
