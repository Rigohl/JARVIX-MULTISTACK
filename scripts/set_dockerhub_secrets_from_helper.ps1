#!/usr/bin/env pwsh
# Extract Docker Hub credentials using the configured docker credential helper
# and create repository secrets DOCKERHUB_USERNAME and DOCKERHUB_TOKEN via gh.
# This script does NOT print secrets.

$ErrorActionPreference = 'Stop'

# Find config file
$paths = @("$env:USERPROFILE\.docker\config.json", "$env:HOME\.docker\config.json", "/root/.docker/config.json")
$cfg = $null
foreach ($p in $paths) {
  if (Test-Path $p) { $cfg = $p; break }
}
if (-not $cfg) { Write-Error "No Docker config found in common locations."; exit 1 }

try {
  $json = Get-Content $cfg -Raw | ConvertFrom-Json
} catch {
  Write-Error "Failed to parse Docker config at $cfg"; exit 2
}

# detect helper
$helper = $null
if ($json.credsStore) {
  $helper = "docker-credential-$($json.credsStore)"
} elseif ($json.credHelpers) {
  foreach ($prop in $json.credHelpers.PSObject.Properties) {
    if ($prop.Name -match 'docker|index.docker.io') { $helper = "docker-credential-$($prop.Value)"; break }
  }
}

if (-not $helper) { Write-Error "No credential helper configured for Docker Hub in $cfg"; exit 3 }

# ensure helper exists
if (-not (Get-Command $helper -ErrorAction SilentlyContinue)) { Write-Error "Credential helper '$helper' not found in PATH."; exit 4 }

# call helper and parse JSON
$stdin = '{"ServerURL":"https://index.docker.io/v1/"}'
try {
  $raw = $stdin | & $helper get 2>$null
} catch {
  Write-Error "Credential helper invocation failed."; exit 5
}
if (-not $raw) { Write-Error "Helper produced no output."; exit 6 }

try {
  $obj = $raw | ConvertFrom-Json
} catch {
  Write-Error "Failed to parse helper output as JSON."; exit 7
}

$usr = $obj.Username
$pw  = $obj.Secret
if (-not $usr -or -not $pw) { Write-Error "Missing Username or Secret in helper output."; exit 8 }

# verify gh exists
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Write-Error "'gh' not found in PATH. Install GitHub CLI and authenticate first."; exit 9 }

# set secrets securely (do not echo values)
$usr | & gh secret set DOCKERHUB_USERNAME -R Rigohl/JARVIX-MULTISTACK -b - | Out-Null
$pw  | & gh secret set DOCKERHUB_TOKEN -R Rigohl/JARVIX-MULTISTACK -b - | Out-Null

Write-Output "SECRETS_SET"
# confirm presence of secrets
& gh secret list -R Rigohl/JARVIX-MULTISTACK --limit 100 | Select-String 'DOCKERHUB_' -SimpleMatch | ForEach-Object { Write-Output $_.ToString() }
