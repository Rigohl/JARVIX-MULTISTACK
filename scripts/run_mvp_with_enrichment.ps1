# JARVIX MVP with Enrichment - Full Pipeline
# Usage: .\run_mvp_with_enrichment.ps1 -RunId "demo_enriched_001"

param(
    [Parameter(Mandatory=$true)]
    [string]$RunId,
    
    [Parameter(Mandatory=$false)]
    [string]$InputFile = "data/seeds.txt"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "JARVIX Pipeline with Enrichment" -ForegroundColor Cyan
Write-Host "Run ID: $RunId" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build Rust enrichment engine
Write-Host "[1/6] Building enrichment engine..." -ForegroundColor Yellow
Push-Location engine
cargo build --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "✓ Build complete" -ForegroundColor Green
Write-Host ""

# Step 2: Initialize enrichment cache
Write-Host "[2/6] Initializing enrichment cache..." -ForegroundColor Yellow
& .\engine\target\release\jarvix-enrichment.exe init-cache
Write-Host "✓ Cache initialized" -ForegroundColor Green
Write-Host ""

# Step 3: Process URLs (if existing MVP components exist)
# Note: This assumes the MVP pipeline exists. If not, we'll skip to enrichment demo
$hasMvpPipeline = Test-Path ".\engine\target\release\jarvix.exe"

if ($hasMvpPipeline) {
    Write-Host "[3/6] Running MVP collection..." -ForegroundColor Yellow
    # & .\engine\target\release\jarvix.exe collect --run $RunId --input $InputFile
    Write-Host "✓ Collection complete (skipped - MVP not fully integrated)" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "[4/6] Running MVP curation..." -ForegroundColor Yellow
    # & .\engine\target\release\jarvix.exe curate --run $RunId
    Write-Host "✓ Curation complete (skipped - MVP not fully integrated)" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "[5/6] Running scoring..." -ForegroundColor Yellow
    # julia science\score.jl $RunId data
    Write-Host "✓ Scoring complete (skipped - MVP not fully integrated)" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "[3/6] MVP pipeline not found, demonstrating enrichment only..." -ForegroundColor Yellow
    Write-Host ""
}

# Step 4: Run enrichment
Write-Host "[6/6] Running enrichment..." -ForegroundColor Yellow

# Demo enrichment with example URLs
$demoUrls = @(
    @{ url = "https://www.shopify.com"; score = 58.0 },
    @{ url = "https://techcrunch.com"; score = 52.0 },
    @{ url = "https://example.com"; score = 45.0 },
    @{ url = "https://github.com"; score = 70.0 }
)

Write-Host "Enriching sample URLs..." -ForegroundColor Cyan
foreach ($item in $demoUrls) {
    Write-Host "  Processing: $($item.url)" -ForegroundColor Gray
    & .\engine\target\release\jarvix-enrichment.exe enrich --url $item.url --score $item.score --format json > "$env:TEMP\enrichment_$($item.url -replace '[^a-zA-Z0-9]', '_').json"
}

Write-Host "✓ Enrichment complete" -ForegroundColor Green
Write-Host ""

# Step 5: Show cache statistics
Write-Host "Cache Statistics:" -ForegroundColor Yellow
& .\engine\target\release\jarvix-enrichment.exe cache-stats
Write-Host ""

# Final summary
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Pipeline Complete!" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Run ID: $RunId" -ForegroundColor White
Write-Host "Enrichment cache: data/jarvix.db" -ForegroundColor White
Write-Host ""
Write-Host "To enrich a batch of scored records:" -ForegroundColor Yellow
Write-Host "  .\engine\target\release\jarvix-enrichment.exe batch --input data\scores\$RunId.jsonl --output data\scores\${RunId}_enriched.jsonl" -ForegroundColor Gray
Write-Host ""
