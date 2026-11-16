param([string]$Repo = (Resolve-Path "$PSScriptRoot/..").Path)
$ErrorActionPreference = "Stop"
$want = "6855c01cf4a1662ba421e6f95370cf9afa2b3ab6c148473c63efe60d634dfb9a"
$dst = "$Repo/installer/tools/xdelta3.exe"
if ((Test-Path $dst) -and ((Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLower() -eq $want)) {
  Write-Output "xdelta3.exe already present and verified"; exit 0
}
$url = "https://github.com/jmacd/xdelta-gpl/releases/download/v3.1.0/xdelta3-3.1.0-x86_64.exe.zip"
$tmp = Join-Path $env:TEMP "xdelta3-dl.zip"
Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
$ex = Join-Path $env:TEMP "xdelta3-dl"
Expand-Archive -LiteralPath $tmp -DestinationPath $ex -Force
$exe = Get-ChildItem -Path $ex -Recurse -Filter "xdelta3*.exe" | Select-Object -First 1
$got = (Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256).Hash.ToLower()
if ($got -ne $want) { throw "downloaded xdelta3 sha mismatch: $got" }
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
Copy-Item -LiteralPath $exe.FullName -Destination $dst -Force
Write-Output "xdelta3.exe fetched and verified $got"