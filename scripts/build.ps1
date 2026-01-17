#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build script for JARVIX MVP
    Compila Rust, instala Node deps, prepara todo para run_mvp.ps1

.EXAMPLE
    ./build.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$JARVIX_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "🔨 Building JARVIX MVP" -ForegroundColor Cyan
Write-Host "Root: $JARVIX_ROOT" -ForegroundColor Gray

# Step 1: Rust
Write-Host ""
Write-Host "📦 Building Rust engine..." -ForegroundColor Green
Push-Location $JARVIX_ROOT/engine
try {
    cargo build 2>&1 | Select-String -Pattern "(error|warning|Finished|Compiling)" | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Rust build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Rust build successful" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Step 2: Node
Write-Host ""
Write-Host "📦 Installing Node dependencies..." -ForegroundColor Green
Push-Location $JARVIX_ROOT/app
try {
    npm install 2>&1 | Select-String -Pattern "(added|removed|up to date)" | Out-Host
    Write-Host "✓ Node dependencies installed" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Step 3: Julia environment (optional, can be skipped if not needed)
Write-Host ""
Write-Host "📦 Checking Julia..." -ForegroundColor Green
try {
    julia --eval "println(\"Julia ready\")" 2>&1 | Out-Host
    Write-Host "✓ Julia available" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Julia not available (optional)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Build complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: Run './scripts/run_mvp.ps1' to execute the pipeline" -ForegroundColor Yellow
