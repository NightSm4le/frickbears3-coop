param([string]$Repo = (Resolve-Path "$PSScriptRoot/..").Path, [string]$Work = (Resolve-Path "$Repo/..").Path)
$ErrorActionPreference = "Stop"
$api = "https://api.github.com/repos/NightSm4le/frickbears3-coop"
$tok = (printf "protocol=https`nhost=github.com`n`n" | git credential-manager get 2>$null | Select-String '^password=').ToString().Substring(9)
if (-not $tok) { throw "no GitHub credential available" }
$H = @{ Authorization = "Bearer $tok"; Accept = "application/vnd.github+json"; "User-Agent" = "fb3-coop-release" }
$rels = Invoke-RestMethod -Uri "$api/releases?per_page=100" -Headers $H
if ($rels | Where-Object { $_.tag_name -eq "v0.8.5" }) { throw "release v0.8.5 already exists - refusing to duplicate" }
$tags = Invoke-RestMethod -Uri "$api/tags?per_page=100" -Headers $H
if ($tags | Where-Object { $_.name -eq "v0.8.5" }) { throw "tag v0.8.5 already exists - refusing to duplicate" }
$body = Get-Content -LiteralPath "$Repo/docs/RELEASE_0.8.5.md" -Raw
$payload = @{ tag_name = "v0.8.5"; target_commitish = "master"; name = "FB3 Co-op 0.8.5"; body = $body; draft = $true; prerelease = $false } | ConvertTo-Json -Depth 4
$rel = Invoke-RestMethod -Method Post -Uri "$api/releases" -Headers $H -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
Write-Output "DRAFT CREATED id=$($rel.id) url=$($rel.html_url) draft=$($rel.draft)"
$upload = $rel.upload_url -replace '\{\?name,label\}', ''
foreach ($f in @("$Work/dist/Freakbear3Coop-0.8.5-Setup.exe", "$Work/dist/FB3-Coop-0.8.5.zip", "$Work/build/pkg/FB3-Coop-0.8.5/SHA256SUMS.txt")) {
  $name = [IO.Path]::GetFileName($f)
  $bytes = [IO.File]::ReadAllBytes($f)
  $r = Invoke-RestMethod -Method Post -Uri ($upload + "?name=" + [Uri]::EscapeDataString($name)) -Headers $H -ContentType "application/octet-stream" -Body $bytes
  Write-Output "ASSET $($r.name) size=$($r.size) state=$($r.state)"
}
Write-Output "DRAFT READY - NOT PUBLISHED. No push, no tag created."