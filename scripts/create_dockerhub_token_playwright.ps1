#!/usr/bin/env pwsh
<##
Wrapper to run Node Playwright script on Windows interactively.
Reads Docker Hub credentials securely and invokes the Node script with env vars.
##>
param(
  [string]$Repo = "Rigohl/JARVIX-MULTISTACK",
  [string]$TokenName = "",
  [switch]$Headless = $false,
  [string]$ProfileDir = "",
  [switch]$DryRun = $false
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Error "Node.js not found in PATH. Install Node.js (https://nodejs.org/)."; exit 1 }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Write-Error "GitHub CLI 'gh' not found in PATH. Install and authenticate (gh auth login)."; exit 2 }

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Write-Warning "npm not found; ensure Playwright is installed (npm i -D playwright)" }

$usr = Read-Host "Docker Hub username or email"
$pw = Read-Host "Docker Hub password" -AsSecureString
$pwdPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw))

if (-not $TokenName -or $TokenName -eq "") { $TokenName = "jarvix-ci-$(Get-Date -Format yyyy-MM-dd)" }

$env:DOCKERHUB_USER = $usr
$env:DOCKERHUB_PASSWORD = $pwdPlain
$env:GITHUB_REPO = $Repo

$cmd = "node"; $args = @("scripts/create_dockerhub_token_playwright.js", "--token-name", "$TokenName")
if ($Headless) { $args += "--headless" }
if ($ProfileDir) { $args += "--profile"; $args += $ProfileDir }
if ($DryRun) { $args += "--dry-run" }

Write-Output "Running Playwright script (not printing secrets). Follow prompts in browser if necessary..."
$proc = Start-Process -FilePath $cmd -ArgumentList $args -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) { Write-Error "Script failed with exit code $($proc.ExitCode)"; exit $proc.ExitCode }
Write-Output "Done. If successful, DOCKERHUB_TOKEN secret was set for $Repo (check via 'gh secret list -R $Repo')."

# Clear plaintext password variable
Remove-Variable pwdPlain -ErrorAction SilentlyContinue
