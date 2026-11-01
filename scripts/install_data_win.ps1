[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)]
    [string]$GameDir,
    [Parameter(Mandatory = $true)]
    [string]$BuiltDataWin
)

$ErrorActionPreference = "Stop"
$game = (Resolve-Path -LiteralPath $GameDir).Path
$source = (Resolve-Path -LiteralPath $BuiltDataWin).Path
$target = Join-Path $game "data.win"
$backup = Join-Path $game "data.win.coop-backup"
$staged = Join-Path $game "data.win.coop-new"

if (!(Test-Path -LiteralPath (Join-Path $game "Frickbears3.exe"))) {
    throw "GameDir must contain Frickbears3.exe."
}
if (!(Test-Path -LiteralPath $target)) {
    throw "GameDir must contain the original data.win."
}
if ([StringComparer]::OrdinalIgnoreCase.Equals($source, $target)) {
    throw "BuiltDataWin must not be the game's current data.win."
}
if (Test-Path -LiteralPath $backup) {
    throw "Backup already exists: $backup. Move it elsewhere before installing another build."
}

$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
if (!$PSCmdlet.ShouldProcess($target, "Replace data.win after preserving the original as data.win.coop-backup")) {
    return
}

try {
    Copy-Item -LiteralPath $source -Destination $staged
    $stagedHash = (Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash
    if ($stagedHash -ne $sourceHash) {
        throw "The staged data.win failed its SHA-256 check."
    }

    Move-Item -LiteralPath $target -Destination $backup
    try {
        Move-Item -LiteralPath $staged -Destination $target
    }
    catch {
        Move-Item -LiteralPath $backup -Destination $target
        throw
    }
    Write-Output "Installed co-op data.win. Original preserved at $backup"
    Write-Output "SHA256 $sourceHash"
}
finally {
    if (Test-Path -LiteralPath $staged) {
        Remove-Item -LiteralPath $staged -Force
    }
}
