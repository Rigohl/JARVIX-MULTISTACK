#!/bin/bash
# Setup cron job for weekly trend analysis
# This script configures a cron job to run trend analysis every 7 days

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCIENCE_DIR="$PROJECT_ROOT/science"

echo "============================================================"
echo "JARVIX Trend Analysis - Cron Job Setup"
echo "============================================================"

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "❌ Julia is not installed. Please install Julia first."
    exit 1
fi

echo "✓ Julia found: $(which julia)"
echo "✓ Project root: $PROJECT_ROOT"

# Create a wrapper script for cron
CRON_WRAPPER="$SCRIPT_DIR/run_weekly_trends.sh"

cat > "$CRON_WRAPPER" << 'EOF'
#!/bin/bash
# Cron wrapper script for weekly trend analysis

# Set up environment
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Log file
LOG_FILE="$PROJECT_ROOT/data/reports/weekly_trends.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Run with logging
echo "=== Weekly Trend Analysis - $(date) ===" >> "$LOG_FILE"
cd "$PROJECT_ROOT" || exit 1

julia "$PROJECT_ROOT/science/weekly_trends.jl" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Success" >> "$LOG_FILE"
    
    # Send email alerts if any
    julia "$PROJECT_ROOT/science/email_alerts.jl" data >> "$LOG_FILE" 2>&1
else
    echo "❌ Failed" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
EOF

chmod +x "$CRON_WRAPPER"
echo "✓ Created cron wrapper: $CRON_WRAPPER"

# Generate crontab entry
CRON_ENTRY="0 2 * * 0 $CRON_WRAPPER"

echo ""
echo "============================================================"
echo "Cron Job Configuration"
echo "============================================================"
echo ""
echo "To schedule weekly trend analysis, add this line to your crontab:"
echo ""
echo "    $CRON_ENTRY"
echo ""
echo "This will run every Sunday at 2:00 AM."
echo ""
echo "To edit your crontab, run:"
echo "    crontab -e"
echo ""
echo "Or to install automatically (Linux/Mac):"
echo "    (crontab -l 2>/dev/null; echo \"$CRON_ENTRY\") | crontab -"
echo ""
echo "============================================================"
echo "Manual Testing"
echo "============================================================"
echo ""
echo "To test the weekly trend analysis manually:"
echo "    $CRON_WRAPPER"
echo ""
echo "Or run the Julia script directly:"
echo "    julia $SCIENCE_DIR/weekly_trends.jl"
echo ""
echo "============================================================"
echo "✅ Setup complete!"
echo "============================================================"
