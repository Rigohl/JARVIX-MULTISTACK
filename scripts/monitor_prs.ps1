#!/usr/bin/env pwsh
# Monitor Copilot PR changes in real-time

while ($true) {
    Clear-Host
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Checking Copilot PRs..." -ForegroundColor Cyan
    Write-Host ""
    
    @(7,8,9,10,11,12) | ForEach-Object {
        $pr = $_
        git fetch origin "pull/$pr/head" --quiet 2>&1
        $commit = git log -1 --format="%h %s" "origin/pull/$pr/head" 2>&1
        
        if ($commit -match "^\w{7}") {
            $status = if ($commit -match "plan|Initial") { "🔄 Planning" } 
                      elseif ($commit -match "impl|Implement") { "⚙️ Implementing" }
                      elseif ($commit -match "test|Test") { "✅ Testing" }
                      else { "📝 $($commit -split ' ' | Select-Object -Last 1)" }
            
            Write-Host "PR #$pr : $status ($commit)"
        }
    }
    
    Write-Host ""
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
    Start-Sleep -Seconds 30
}
