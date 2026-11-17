param([string]$Repo = (Resolve-Path "$PSScriptRoot/..").Path, [string]$Work = (Resolve-Path "$Repo/..").Path)
$ErrorActionPreference = "Stop"
$api = "https://api.github.com/repos/NightSm4le/frickbears3-coop"
$tok = (printf "protocol=https`nhost=github.com`n`n" | git credential-manager get 2>$null | Select-String '^password=').ToString().Substring(9)
if (-not $tok) { throw "no GitHub credential available" }
$H = @{ Authorization = "Bearer $tok"; Accept = "application/vnd.github+json"; "User-Agent" = "fb3-coop-release" }
$rels = Invoke-RestMethod -Uri "$api/releases?per_page=100" -Headers $H
$existing = $rels | Where-Object { $_.tag_name -eq "v0.8.6" }
if ($existing -and -not $existing.draft) { throw "release v0.8.6 already published - refusing to duplicate" }
$tags = Invoke-RestMethod -Uri "$api/tags?per_page=100" -Headers $H
if ($tags | Where-Object { $_.name -eq "v0.8.6" }) { throw "tag v0.8.6 already exists - refusing to duplicate" }
$body = [IO.File]::ReadAllText("$Repo/docs/RELEASE_0.8.6.md", [System.Text.Encoding]::UTF8)
if ($existing) {
  $rel = $existing
  Write-Output "DRAFT REUSED id=$($rel.id) url=$($rel.html_url) draft=$($rel.draft)"
  $patch = @{ name = "FB3 Co-op 0.8.6"; body = $body; draft = $true; prerelease = $false } | ConvertTo-Json -Depth 4
  $rel = Invoke-RestMethod -Method Patch -Uri "$api/releases/$($rel.id)" -Headers $H -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($patch))
  Write-Output "DRAFT BODY UPDATED from docs/RELEASE_0.8.6.md"
  foreach ($a in @($rel.assets)) {
    if ($a.name -in @("Freakbear3Coop-0.8.6-Setup.exe", "FB3-Coop-0.8.6.zip", "SHA256SUMS.txt")) {
      Invoke-RestMethod -Method Delete -Uri "$api/releases/assets/$($a.id)" -Headers $H | Out-Null
      Write-Output "STALE ASSET DELETED: $($a.name) (will re-upload)"
    }
  }
} else {
  $payload = @{ tag_name = "v0.8.6"; target_commitish = "master"; name = "FB3 Co-op 0.8.6"; body = $body; draft = $true; prerelease = $false } | ConvertTo-Json -Depth 4
  $rel = Invoke-RestMethod -Method Post -Uri "$api/releases" -Headers $H -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
  Write-Output "DRAFT CREATED id=$($rel.id) url=$($rel.html_url) draft=$($rel.draft)"
}
$upload = $rel.upload_url -replace '\{\?name,label\}', ''
foreach ($f in @("$Work/dist/Freakbear3Coop-0.8.6-Setup.exe", "$Work/dist/FB3-Coop-0.8.6.zip", "$Work/build/pkg/FB3-Coop-0.8.6/SHA256SUMS.txt")) {
  $name = [IO.Path]::GetFileName($f)
  $bytes = [IO.File]::ReadAllBytes($f)
  for ($attempt = 1; ; $attempt++) {
    try {
      $r = Invoke-RestMethod -Method Post -Uri ($upload + "?name=" + [Uri]::EscapeDataString($name)) -Headers $H -ContentType "application/octet-stream" -Body $bytes
      Write-Output "ASSET $($r.name) size=$($r.size) state=$($r.state)"
      break
    } catch {
      if ($attempt -ge 3) { throw }
      Write-Output "upload attempt $attempt failed, retrying: $($_.Exception.Message)"
      Start-Sleep -Seconds 3
    }
  }
}
Write-Output "DRAFT READY - NOT PUBLISHED. No push, no tag created."