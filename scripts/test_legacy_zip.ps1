param([string]$Repo = (Resolve-Path "$PSScriptRoot/..").Path, [string]$Work = (Resolve-Path "$Repo/..").Path)
$ErrorActionPreference = "Stop"
function Sha($p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() }
$m = Get-Content "$Repo/installer/patches/manifest.json" -Raw | ConvertFrom-Json
$z = "$Work/testgame/zip085"
Remove-Item $z -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -LiteralPath "$Work/dist/FB3-Coop-0.8.5.zip" -DestinationPath $z -Force
$pkg = "$z/FB3-Coop-0.8.5"
$g = "$Work/testgame/game"
$before = Sha "$g/data.win"
$cur = $before
$base = ($m.bases | Where-Object { $_.sha -eq $cur }).name
if (-not $base) {
  $bak = Sha "$g/data.win.coop-original"
  $base = ($m.bases | Where-Object { $_.sha -eq $bak }).name
}
if (-not $base) { throw "legacy test: game copy base not recognized" }
$want = ($m.targets | Where-Object { $_.base -eq $base -and $_.variant -eq "std" }).out
$dest = "$Work/testgame/legacy-copy"
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
& powershell -NoProfile -ExecutionPolicy Bypass -File "$pkg/install.ps1" -GameDir $g -DestName "legacy-copy" -Variant std
if ($LASTEXITCODE -ne 0) { throw "legacy install.ps1 exit $LASTEXITCODE" }
$got = Sha "$dest/data.win"
if ($got -ne $want) { throw "legacy zip output sha $got != $want" }
if ((Sha "$g/data.win") -ne $before) { throw "legacy install modified the source game folder" }
if (-not (Test-Path "$dest/data.win.coop-original")) { throw "legacy copy missing backup" }
Remove-Item $dest -Recurse -Force
Remove-Item $z -Recurse -Force
Write-Output "LEGACY ZIP TEST PASSED (base=$base variant=std, source untouched)"