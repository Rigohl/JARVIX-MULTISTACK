#!/usr/bin/env pwsh
# Auto-integrate Copilot PRs after Phase completion

param (
    [int]$PRNumber = 7,
    [string]$PhaseDir = ""
)

function Test-Phase {
    param (
        [int]$PR,
        [string]$Dir
    )
    
    Write-Host "🧪 Testing Phase PR #$PR ($Dir)" -ForegroundColor Blue
    
    switch ($PR) {
        7 { 
            # Phase 1: Test actions.jl
            julia "$Dir/actions.jl" --test
            if ($LASTEXITCODE -eq 0) { return $true }
        }
        8 {
            # Phase 4: Test pdf.ts
            npm run test -- "$Dir/pdf.ts"
            if ($LASTEXITCODE -eq 0) { return $true }
        }
        10 {
            # Phase 2: Test discovery.rs
            cd engine && cargo test --release --lib discovery
            if ($LASTEXITCODE -eq 0) { return $true }
        }
        11 {
            # Phase 5: Test enrichment.rs
            cd engine && cargo test --release --lib enrichment
            if ($LASTEXITCODE -eq 0) { return $true }
        }
        9 {
            # Phase 3: Test trends.jl
            julia "$Dir/trends.jl" --test
            if ($LASTEXITCODE -eq 0) { return $true }
        }
        12 {
            # Phase 6: Test parallel.rs
            cd engine && cargo test --release --lib parallel
            if ($LASTEXITCODE -eq 0) { return $true }
        }
    }
    
    return $false
}

function Merge-PR {
    param (
        [int]$PR
    )
    
    Write-Host "✅ Merging PR #$PR to main" -ForegroundColor Green
    git fetch origin "pull/$PR/head:phase-$PR"
    git checkout main
    git merge --no-ff "phase-$PR" -m "Merge Phase $(Get-Map $PR) implementation"
    git push origin main
    Write-Host "✅ Merged to main successfully" -ForegroundColor Green
}

function Get-Map {
    param ([int]$PR)
    @{7="1"; 8="4"; 9="3"; 10="2"; 11="5"; 12="6"}[$PR]
}

Write-Host "JARVIX Copilot Integration Pipeline Started" -ForegroundColor Yellow
Write-Host ""

if (Test-Phase -PR $PRNumber -Dir $PhaseDir) {
    Merge-PR -PR $PRNumber
} else {
    Write-Host "❌ Tests failed for PR #$PRNumber - Not merging" -ForegroundColor Red
}
