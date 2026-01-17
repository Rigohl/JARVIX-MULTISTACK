# JARVIX Verify.ps1
# Verificacion completa del entorno

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

function Write-Check { param([string]$Name, [bool]$Ok, [string]$Info)
    $Status = if ($Ok) { "[OK]" } else { "[X]" }
    $Color = if ($Ok) { "Green" } else { "Red" }
    Write-Host "  $Status $Name`: $Info" -ForegroundColor $Color
}

Write-Host "`n=== JARVIX Verification ===" -ForegroundColor Cyan

# Tools
Write-Host "`n[TOOLS]" -ForegroundColor Blue
$CmdsOk = @("Git", "Node.js", "Npm", "Python", "Rust", "Cargo", "Julia", "SQLite") | ForEach-Object {
    if (Get-Command $_.ToLower() -EA SilentlyContinue) {
        $Ver = & $_.ToLower() "--version" 2>&1 | Select-Object -First 1
        Write-Check $_ $true "$Ver"
    } else {
        Write-Check $_ $false ""
    }
}

# Project Folders
Write-Host "`n[FOLDERS]" -ForegroundColor Blue
$Folders = @(
    "app", "engine", "science", "train", "data", "scripts", "docs"
)
foreach ($F in $Folders) {
    Write-Check $F (Test-Path $F) ""
}

# Python Environment
Write-Host "`n[PYTHON]" -ForegroundColor Blue
$VenvPath = "train\.venv\Scripts\Activate.ps1"
if (Test-Path $VenvPath) {
    & $VenvPath 2>&1 | Out-Null
    Write-Check "Venv" $true (python --version 2>&1)
    
    $Pkgs = @("numpy", "pandas", "jax", "jupyter")
    foreach ($P in $Pkgs) {
        $Check = python -c "import $P" 2>&1
        Write-Check "  - $P" ($LASTEXITCODE -eq 0) ""
    }
    
    # JAX Test
    $JaxTest = python -c "import jax; print(jax.devices())" 2>&1
    Write-Check "JAX devices" ($LASTEXITCODE -eq 0) "$JaxTest"
    
    deactivate 2>&1 | Out-Null
}

# Files
Write-Host "`n[FILES]" -ForegroundColor Blue
Write-Check "README.md" (Test-Path "README.md") ""
Write-Check "data/schema.sql" (Test-Path "data\schema.sql") ""
Write-Check "data/jarvix.db" (Test-Path "data\jarvix.db") ""
Write-Check ".env" (Test-Path ".env") ""
Write-Check "engine/Cargo.toml" (Test-Path "engine\Cargo.toml") ""
Write-Check "app/package.json" (Test-Path "app\package.json") ""

# GPU Check
Write-Host "`n[GPU]" -ForegroundColor Blue
if (Get-Command nvidia-smi -EA SilentlyContinue) {
    $GPU = nvidia-smi --query-gpu=name --format=csv,noheader 2>&1 | Select-Object -First 1
    Write-Check "NVIDIA GPU" $true "$GPU"
} else {
    Write-Check "NVIDIA GPU" $false "No detectada"
}

Write-Host ""
