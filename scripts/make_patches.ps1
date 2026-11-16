param([string]$Repo = (Resolve-Path "$PSScriptRoot/..").Path, [string]$Work = (Resolve-Path "$Repo/..").Path)
$ErrorActionPreference = "Stop"
$xd = "$Repo/installer/tools/xdelta3.exe"
$xdSha = (Get-FileHash -LiteralPath $xd -Algorithm SHA256).Hash.ToLower()
if ($xdSha -ne "6855c01cf4a1662ba421e6f95370cf9afa2b3ab6c148473c63efe60d634dfb9a") { throw "xdelta3.exe sha mismatch: $xdSha" }
$mp = "$Repo/installer/patches/manifest.json"
$m = Get-Content $mp -Raw | ConvertFrom-Json
$baseFiles = @{
  clean215 = "C:/Users/PC/Desktop/Original/data.win"
  coop072 = "$Work/dl/coopinstall072/Coop_Install/data.win"
  std082 = "$Work/bases/data082std.win"
  unlock082 = "$Work/bases/data082unlock.win"
}
foreach ($t in $m.targets) {
  $src = $baseFiles[$t.base]
  $out = "$Work/build/matrix/$($t.base)_$($t.variant).win"
  $patch = "$Repo/installer/patches/$($t.patch)"
  & $xd -e -9 -f -s $src $out $patch
  if ($LASTEXITCODE -ne 0) { throw "encode $($t.patch)" }
  $rt = "$Work/build/matrix/rt_$($t.base)_$($t.variant).win"
  & $xd -d -f -s $src $patch $rt
  if ($LASTEXITCODE -ne 0) { throw "decode $($t.patch)" }
  $sha = (Get-FileHash -LiteralPath $rt -Algorithm SHA256).Hash.ToLower()
  if ($sha -ne $t.out) { throw "round-trip mismatch $($t.patch): $sha != $($t.out)" }
  Remove-Item $rt
  $psha = (Get-FileHash -LiteralPath $patch -Algorithm SHA256).Hash.ToLower()
  $t | Add-Member -NotePropertyName patchSha -NotePropertyValue $psha -Force
  Write-Output "PATCH OK $($t.patch) $psha"
}
$m | ConvertTo-Json -Depth 6 | Set-Content $mp -Encoding UTF8
Write-Output "PATCHES DONE"