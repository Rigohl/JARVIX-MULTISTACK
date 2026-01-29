#!/usr/bin/env pwsh
<##
.SYNOPSIS
  Read Docker Hub Personal Access Token from clipboard and save it as a GitHub Actions repository secret DOCKERHUB_TOKEN.

.DESCRIPTION
  This helper reads the clipboard (Windows) and sets the value as a GitHub Actions repository secret using `gh secret set`.
  The token is not echoed to the console. The script will also optionally set DOCKERHUB_USERNAME if it is not present.

.NOTES
  - Requirements: GitHub CLI (`gh`) installed and authenticated (`gh auth login`).
  - Create the Docker Hub token first at: https://hub.docker.com/settings/security
  - Run this script from the repository root:
      .\scripts\set_dockerhub_token_from_clipboard.ps1
##>

param(
    [string]$Repo = "Rigohl/JARVIX-MULTISTACK"
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "'gh' not found in PATH. Install GitHub CLI (https://cli.github.com/) and authenticate first (gh auth login)."
    exit 1
}
try {
    & gh auth status 2>$null | Out-Null
} catch {
    Write-Error "GitHub CLI not authenticated. Run 'gh auth login' and try again."
    exit 2
}

# Read from clipboard
try {
    $token = Get-Clipboard -TextFormat Text
} catch {
    Write-Error "Could not read clipboard. Copy the access token to the clipboard and try again."
    exit 3
}
if (-not $token -or $token.Trim().Length -lt 10) {
    Write-Error "Clipboard doesn't look like a token. Copy the token to the clipboard and try again."
    exit 4
}

# Set secret via gh (stdin)
$token | & gh secret set DOCKERHUB_TOKEN -R $Repo -b - | Out-Null
Write-Output "DOCKERHUB_TOKEN set for $Repo"

# Optionally set DOCKERHUB_USERNAME if missing
try {
    $names = & gh secret list -R $Repo --json name -q '.[] | .name'
} catch {
    Write-Warning "Could not list secrets. DOCKERHUB_TOKEN appears set but could not verify DOCKERHUB_USERNAME presence."
    exit 0
}

if (-not ($names | Select-String 'DOCKERHUB_USERNAME' -SimpleMatch)) {
    $user = Read-Host "No DOCKERHUB_USERNAME secret found. Enter Docker Hub username to set as DOCKERHUB_USERNAME (or press Enter to skip)"
    if ($user -and $user.Trim()) {
        $user.Trim() | & gh secret set DOCKERHUB_USERNAME -R $Repo -b - | Out-Null
        Write-Output "DOCKERHUB_USERNAME set"
    }
}
