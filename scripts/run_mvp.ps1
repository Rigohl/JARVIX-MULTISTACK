#!/usr/bin/env pwsh
<#
.SYNOPSIS
JARVIX MVP Pipeline Orchestrator
.DESCRIPTION
Executes complete end-to-end pipeline: migrate → collect → curate → score → report
.PARAMETER RunId
Run identifier (default: timestamp)
.EXAMPLE
.\run_mvp.ps1 -RunId "demo_001"
#>

param(
    [string]$RunId = (Get-Date -Format "yyyyMMdd_HHmmss"),
    [string]$DataDir = "./data"
)

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

Write-Host ""
Write-Host "JARVIX MVP PIPELINE - $RunId" -ForegroundColor Cyan
Write-Host ""

# Set executable path
$exe = Join-Path $PSScriptRoot "..\engine\target\release\jarvix.exe"
if (-not (Test-Path $exe)) {
    Write-Host "ERROR: jarvix.exe not found" -ForegroundColor Red
    exit 1
}

$dbPath = Join-Path $DataDir "jarvix.db"

# Step 1: Migrate
Write-Host "1/5 Migrating database..." -ForegroundColor Cyan
& $exe migrate $dbPath 2>&1 | Write-Host -ForegroundColor Green
Write-Host ""

# Step 2: Collect
Write-Host "2/5 Collecting URLs..." -ForegroundColor Cyan
$inputFile = Join-Path $DataDir "seeds.txt"
& $exe collect --run $RunId --input $inputFile --db $dbPath 2>&1 | Write-Host -ForegroundColor Green
Write-Host ""

# Step 3: Curate
Write-Host "3/5 Curating data..." -ForegroundColor Cyan
& $exe curate --run $RunId --db $dbPath 2>&1 | Write-Host -ForegroundColor Green
Write-Host ""

# Step 4: Score
Write-Host "4/5 Scoring (Julia)..." -ForegroundColor Cyan
julia -e 'using Pkg; Pkg.add("JSON"; skip_instantiate_check=true)' 2>&1 | Out-Null
$scoreScript = Join-Path $PSScriptRoot "..\science\score.jl"
& julia $scoreScript $RunId $DataDir 2>&1 | Write-Host -ForegroundColor Green
Write-Host ""

# Step 5: Report
Write-Host "5/5 Generating report..." -ForegroundColor Cyan
$reportScript = Join-Path $PSScriptRoot "..\app\report.ts"
& npx ts-node $reportScript $RunId $DataDir 2>&1 | Write-Host -ForegroundColor Green
Write-Host ""

Write-Host "✅ PIPELINE COMPLETE" -ForegroundColor Green
Write-Host "   Report: $DataDir\reports\$RunId.html" -ForegroundColor Cyan
Write-Host ""
