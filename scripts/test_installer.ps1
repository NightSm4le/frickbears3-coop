param(
  [string]$Setup = (Resolve-Path "$PSScriptRoot/../../dist/Freakbear3Coop-0.8.6-Setup.exe").Path,
  [string]$GameSrc = "C:/Users/PC/Desktop/frickbears3-4ld-v2.1.5 (1)",
  [string]$Work = (Resolve-Path "$PSScriptRoot/../..").Path,
  [switch]$SkipBoot
)
$ErrorActionPreference = "Stop"
$g = "$Work/testgame/game"
$results = "$Work/testgame/RESULTS.txt"
New-Item -ItemType Directory -Force -Path "$Work/testgame" | Out-Null
Set-Content $results "installer test run $(Get-Date -Format s)"
function Note($s) { Add-Content $results $s; Write-Output $s }
function Sha($p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() }
$m = Get-Content "$PSScriptRoot/../installer/patches/manifest.json" -Raw | ConvertFrom-Json
function OutSha($b, $v) { ($m.targets | Where-Object { $_.base -eq $b -and $_.variant -eq $v }).out }
function BaseSha($b) { ($m.bases | Where-Object { $_.name -eq $b }).sha }
$baseFiles = @{
  clean215 = "C:/Users/PC/Desktop/Original/data.win"
  coop072 = "$Work/dl/coopinstall072/Coop_Install/data.win"
  std082 = "$Work/bases/data082std.win"
  unlock082 = "$Work/bases/data082unlock.win"
  v202 = "C:/Users/PC/Desktop/frickbears3-4ld-v2.0.2/data.win"
}
if (-not (Test-Path "$g/Frickbears3.exe")) {
  New-Item -ItemType Directory -Force -Path $g | Out-Null
  robocopy $GameSrc $g /E /XF data.win data.win.bak-0.8.2 coop_install_log.txt /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed $LASTEXITCODE" }
}
function Reset-Game($b) {
  Copy-Item -LiteralPath $baseFiles[$b] -Destination "$g/data.win" -Force
  Remove-Item "$g/data.win.coop-original" -Force -ErrorAction SilentlyContinue
  Remove-Item "$g/data.win.coop-new" -Force -ErrorAction SilentlyContinue
}
function Run-Setup($dir, $v, $expectOk) {
  $log = "$Work/testgame/setup_$([guid]::NewGuid().ToString('N').Substring(0,8)).log"
  $args = @('/SILENT', '/SUPPRESSMSGBOXES', "/DIR=$dir", "/LOG=$log", "/VARIANT=$v")
  $p = Start-Process -FilePath $Setup -ArgumentList $args -Wait -PassThru
  $code = $p.ExitCode
  if ($expectOk -and $code -ne 0) { throw "setup exit $code (expected 0), log $log" }
  if (-not $expectOk -and $code -eq 0) { throw "setup exit 0 (expected failure), log $log" }
  return $code
}
function Expect-Sha($p, $want, $label) {
  $got = Sha $p
  if ($got -ne $want) { throw "$label sha $got != $want" }
  Note "PASS $label"
}
foreach ($n in @("Host.bat", "Join.bat", "README_RU.txt", "CONNECT_RU.md", "CUSTOM_CHARACTERS_RU.md", "XDELTA_LICENSE.txt")) {
  Remove-Item "$g/$n" -Force -ErrorAction SilentlyContinue
}

# 1 clean215 std
Reset-Game clean215
Run-Setup $g std $true | Out-Null
Expect-Sha "$g/data.win" (OutSha clean215 std) "case1 clean215+std output"
Expect-Sha "$g/data.win.coop-original" (BaseSha clean215) "case1 backup"
if (Test-Path "$g/data.win.coop-new") { throw "case1 leftover staged file" }
# 2 clean215 unlock
Reset-Game clean215
Run-Setup $g unlock $true | Out-Null
Expect-Sha "$g/data.win" (OutSha clean215 unlock) "case2 clean215+unlock output"
# 3 unlock082 unlock (upgrade path)
Reset-Game unlock082
Run-Setup $g unlock $true | Out-Null
Expect-Sha "$g/data.win" (OutSha unlock082 unlock) "case3 unlock082+unlock output"
Expect-Sha "$g/data.win.coop-original" (BaseSha unlock082) "case3 backup"
# 4 repeat install
$b4 = Sha "$g/data.win.coop-original"
Run-Setup $g unlock $true | Out-Null
Expect-Sha "$g/data.win" (OutSha unlock082 unlock) "case4 repeat install output"
Expect-Sha "$g/data.win.coop-original" $b4 "case4 backup untouched"
if (Test-Path "$g/data.win.coop-new") { throw "case4 leftover staged file" }
# 5 variant switch
Run-Setup $g std $true | Out-Null
Expect-Sha "$g/data.win" (OutSha unlock082 std) "case5 variant switch output"
Expect-Sha "$g/data.win.coop-original" $b4 "case5 backup untouched"
# 6 uninstall restore
$added = @()
if (Test-Path "$g/coop_install_log.txt") {
  $added = Get-Content "$g/coop_install_log.txt" | Where-Object { $_ -like 'added *' } | ForEach-Object { $_.Substring(6) }
}
$u = Start-Process -FilePath "$g/unins000.exe" -ArgumentList '/SILENT', '/SUPPRESSMSGBOXES' -Wait -PassThru
if ($u.ExitCode -ne 0) { throw "uninstall exit $($u.ExitCode)" }
Start-Sleep -Seconds 2
Expect-Sha "$g/data.win" (BaseSha unlock082) "case6 uninstall restored original"
foreach ($n in $added) { if (Test-Path "$g/$n") { throw "case6 added file not cleaned: $n" } }
Note "PASS case6 added-file cleanup ($($added.Count) files)"
# 7 coop072 std
Reset-Game coop072
Run-Setup $g std $true | Out-Null
Expect-Sha "$g/data.win" (OutSha coop072 std) "case7 coop072+std output"
# 8 wrong folder
$empty = "$Work/testgame/empty"
New-Item -ItemType Directory -Force -Path $empty | Out-Null
Run-Setup $empty std $false | Out-Null
Note "PASS case8 wrong folder rejected"
# 9 unsupported base
Reset-Game v202
Run-Setup $g std $false | Out-Null
Expect-Sha "$g/data.win" (Sha $baseFiles['v202']) "case9 unsupported base untouched"
Note "PASS case9 unsupported base rejected"
# 10 boot test on a patched copy
Reset-Game unlock082
Run-Setup $g unlock $true | Out-Null
if (-not $SkipBoot) {
  Start-Process -FilePath "$g/Frickbears3.exe" -WorkingDirectory $g
  Start-Sleep -Seconds 14
  $p = Get-Process Frickbears3 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { throw "boot: game window not found" }
  Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinBoot {
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
  Add-Type -AssemblyName System.Drawing
  $r = New-Object WinBoot+RECT
  [WinBoot]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
  $w = $r.R - $r.L; $h = $r.B - $r.T
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $gr = [System.Drawing.Graphics]::FromImage($bmp)
  $hdc = $gr.GetHdc()
  $ok = [WinBoot]::PrintWindow($p.MainWindowHandle, $hdc, 2)
  $gr.ReleaseHdc(); $gr.Dispose()
  $bmp.Save("$Work/testgame/boot.png")
  $bmp.Dispose()
  Stop-Process -Name Frickbears3 -Force -ErrorAction SilentlyContinue
  if (-not $ok -or $w -lt 100) { throw "boot capture failed" }
  Note "PASS case10 boot capture saved testgame/boot.png (visual check required)"
}
Note "ALL INSTALLER TESTS PASSED"