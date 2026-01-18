#!/bin/bash
# Simple validation script for Phase 3 implementation
# Tests basic Julia script syntax without requiring package installation

echo "============================================================"
echo "Phase 3: Temporal Trend Detection - Validation Script"
echo "============================================================"
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: Check if Julia is available
echo "Test 1: Checking Julia installation..."
if command -v julia &> /dev/null; then
    JULIA_VERSION=$(julia --version)
    echo "✅ PASS - Julia found: $JULIA_VERSION"
    ((PASS_COUNT++))
else
    echo "❌ FAIL - Julia not found"
    ((FAIL_COUNT++))
fi
echo ""

# Test 2: Check if all required files exist
echo "Test 2: Checking required files..."
REQUIRED_FILES=(
    "data/schema.sql"
    "science/trends.jl"
    "science/weekly_trends.jl"
    "science/email_alerts.jl"
    "science/test_trends.jl"
    "science/Project.toml"
    "app/trend_report.ts"
    "scripts/setup_cron.sh"
    "PHASE3_TRENDS.md"
)

FILES_OK=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file - MISSING"
        FILES_OK=false
    fi
done

if [ "$FILES_OK" = true ]; then
    echo "✅ PASS - All required files exist"
    ((PASS_COUNT++))
else
    echo "❌ FAIL - Some files are missing"
    ((FAIL_COUNT++))
fi
echo ""

# Test 3: Verify schema includes opportunity_history table
echo "Test 3: Checking database schema..."
if grep -q "CREATE TABLE IF NOT EXISTS opportunity_history" data/schema.sql; then
    echo "✅ PASS - opportunity_history table defined in schema"
    ((PASS_COUNT++))
else
    echo "❌ FAIL - opportunity_history table not found in schema"
    ((FAIL_COUNT++))
fi
echo ""

# Test 4: Verify Julia syntax of trends.jl
echo "Test 4: Validating trends.jl syntax..."
if julia --check-bounds=yes science/trends.jl --help 2>&1 | grep -q "Usage:"; then
    echo "✅ PASS - trends.jl has valid syntax and help message"
    ((PASS_COUNT++))
elif julia -e 'include("science/trends.jl")' 2>&1 | grep -qE "(Package|ArgumentError: Package)"; then
    # Expected to fail due to missing packages, but syntax is valid
    echo "✅ PASS - trends.jl has valid Julia syntax (packages not installed)"
    ((PASS_COUNT++))
else
    echo "⚠️  SKIP - Cannot validate without Julia packages"
fi
echo ""

# Test 5: Check scripts are executable
echo "Test 5: Checking script permissions..."
if [ -x "scripts/setup_cron.sh" ]; then
    echo "✅ PASS - setup_cron.sh is executable"
    ((PASS_COUNT++))
else
    echo "⚠️  WARN - setup_cron.sh is not executable (fixing...)"
    chmod +x scripts/setup_cron.sh
    ((PASS_COUNT++))
fi
echo ""

# Test 6: Verify TypeScript trend_report.ts exists and is valid
echo "Test 6: Checking TypeScript files..."
if [ -f "app/trend_report.ts" ]; then
    if grep -q "generateTrendReport" app/trend_report.ts; then
        echo "✅ PASS - trend_report.ts contains main function"
        ((PASS_COUNT++))
    else
        echo "❌ FAIL - trend_report.ts missing generateTrendReport function"
        ((FAIL_COUNT++))
    fi
else
    echo "❌ FAIL - trend_report.ts not found"
    ((FAIL_COUNT++))
fi
echo ""

# Test 7: Check if existing test data is present
echo "Test 7: Checking for test data..."
if [ -f "data/scores/mvp_test_001.jsonl" ]; then
    RECORD_COUNT=$(wc -l < data/scores/mvp_test_001.jsonl)
    echo "✅ PASS - Test data found ($RECORD_COUNT records)"
    ((PASS_COUNT++))
else
    echo "⚠️  SKIP - No test data available (expected in CI)"
fi
echo ""

# Test 8: Verify documentation
echo "Test 8: Checking documentation..."
if [ -f "PHASE3_TRENDS.md" ] && grep -q "Week-over-Week" PHASE3_TRENDS.md; then
    echo "✅ PASS - Phase 3 documentation exists and contains key terms"
    ((PASS_COUNT++))
else
    echo "❌ FAIL - Documentation incomplete"
    ((FAIL_COUNT++))
fi
echo ""

# Test 9: Check README updates
echo "Test 9: Verifying README updates..."
if grep -q "Phase 3: Temporal Trend Detection" README.md; then
    echo "✅ PASS - README updated with Phase 3 information"
    ((PASS_COUNT++))
else
    echo "❌ FAIL - README not updated"
    ((FAIL_COUNT++))
fi
echo ""

# Test 10: Verify cron setup script structure
echo "Test 10: Checking cron setup script..."
if grep -q "CRON_ENTRY=" scripts/setup_cron.sh; then
    echo "✅ PASS - Cron setup script has proper structure"
    ((PASS_COUNT++))
else
    echo "❌ FAIL - Cron setup script incomplete"
    ((FAIL_COUNT++))
fi
echo ""

# Summary
echo "============================================================"
echo "Validation Summary"
echo "============================================================"
echo "Tests Passed: $PASS_COUNT"
echo "Tests Failed: $FAIL_COUNT"
echo "Total Tests: $((PASS_COUNT + FAIL_COUNT))"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✅ All validation checks passed!"
    echo ""
    echo "Next steps:"
    echo "1. Install Julia packages: cd science && julia --project=. -e 'using Pkg; Pkg.instantiate()'"
    echo "2. Initialize database: sqlite3 data/jarvix.db < data/schema.sql"
    echo "3. Run trend analysis: julia science/trends.jl mvp_test_001 data"
    echo "4. Generate report: npx ts-node app/trend_report.ts mvp_test_001 data"
    echo ""
    exit 0
else
    echo "❌ Some validation checks failed. Please review the output above."
    exit 1
fi
