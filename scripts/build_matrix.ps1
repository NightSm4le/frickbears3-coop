param([string]$Repo = (Resolve-Path "$PSScriptRoot/..").Path,
      [string]$Work = (Resolve-Path "$Repo/..").Path,
      [string]$Cli = "$Work/tools/utmt/UndertaleModCli.exe")
$ErrorActionPreference = "Stop"
$bases = [ordered]@{
  clean215  = @{ sha = "c254b690b0e2ac7f52914fecc24d4753106a3daf893b11252c3c43ec5ae0df5b"; file = "C:/Users/PC/Desktop/Original/data.win"; stage = "full" }
  coop072   = @{ sha = "12405aa08784f0fd9e0298a73ed1dd68106cf523f4754bbda390649fc0f6dcc2"; file = "$Work/dl/coopinstall072/Coop_Install/data.win"; stage = "overlay" }
  std082    = @{ sha = "726022dae9f9c06c2ab058cda5fefda19c1d10d61c00805ed44309e5d53b59b0"; file = "$Work/bases/data082std.win"; stage = "overlay" }
  unlock082 = @{ sha = "73a4675086ccf3eaed075de11800e809ffb889aeefe275b0b235f6b047fb50b4"; file = "$Work/bases/data082unlock.win"; stage = "overlay" }
}
$outDir = "$Work/build/matrix"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path "$Repo/installer/patches" | Out-Null
$targets = @()
foreach ($bn in $bases.Keys) {
  $b = $bases[$bn]
  $got = (Get-FileHash -LiteralPath $b.file -Algorithm SHA256).Hash.ToLower()
  if ($got -ne $b.sha) { throw "base $bn sha mismatch: $got" }
  foreach ($v in @("std", "unlock")) {
    $out = "$outDir/${bn}_${v}.win"
    $env:COOP_MOD_DIR = $Repo; $env:COOP_STAGE = $b.stage
    $env:COOP_CHEATS = "0"; $env:COOP_UNLOCKALL = $(if ($v -eq "unlock") { "1" } else { "0" })
    & $Cli load $b.file -s "$Repo/scripts/apply.csx" -o $out -f *> "$out.build.log"
    if ($LASTEXITCODE -ne 0) { throw "build $bn/$v failed, see $out.build.log" }
    $env:COOP_STAGE = "full"
    $vt = & $Cli load $out -s "$Repo/tests/verify.csx" 2>&1 | Out-String
    Set-Content "$out.verify.log" $vt
    if ($vt -notmatch "VERIFY OK full") { throw "verify $bn/$v failed: $vt" }
    $sha = (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToLower()
    $targets += [ordered]@{ base = $bn; variant = $v; out = $sha; patch = "p_${bn}_${v}.xdelta"; file = $out }
    Write-Output "OK $bn/$v $sha"
  }
}
$manifest = [ordered]@{
  version = "0.8.6"
  bases = @($bases.Keys | ForEach-Object { [ordered]@{ name = $_; sha = $bases[$_].sha } })
  targets = $targets
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content "$Repo/installer/patches/manifest.json" -Encoding UTF8
$iss = @()
foreach ($t in $targets) { $iss += "#define OutSha_$($t.base)_$($t.variant) `"$($t.out)`"" }
foreach ($bn in $bases.Keys) { $iss += "#define BaseSha_$bn `"$($bases[$bn].sha)`"" }
$iss | Set-Content "$Repo/installer/matrix.iss" -Encoding UTF8
Write-Output "MATRIX DONE"