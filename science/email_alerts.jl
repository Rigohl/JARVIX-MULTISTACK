#!/usr/bin/env julia
# Email Alert Script for Significant Trend Improvements

using JSON
using Dates

"""
    send_email_alert(alert_file::String)

Send email alerts for URLs with significant improvements (>20%).
This is a placeholder that would integrate with a real email service.
"""
function send_email_alert(alert_file::String)
    if !isfile(alert_file)
        println("⚠️  Alert file not found: $alert_file")
        return false
    end
    
    # Load alert data
    alert_data = JSON.parsefile(alert_file)
    alerts = get(alert_data, "alerts", [])
    run_id = get(alert_data, "run_id", "unknown")
    timestamp = get(alert_data, "timestamp", "")
    
    if isempty(alerts)
        println("✓ No alerts to send")
        return true
    end
    
    # Generate email content
    email_subject = "JARVIX Alert: $(length(alerts)) Significant Opportunity Improvement(s)"
    
    email_body = """
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; }
            .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; }
            .alert-item { 
                background-color: #f9f9f9; 
                border-left: 4px solid #4CAF50; 
                margin: 10px 0; 
                padding: 15px; 
            }
            .metric { font-weight: bold; color: #4CAF50; font-size: 1.2em; }
            .footer { margin-top: 30px; padding: 20px; background-color: #f1f1f1; font-size: 0.9em; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🚀 JARVIX Trend Alert</h1>
            <p>Significant Opportunity Improvements Detected</p>
        </div>
        
        <div class="content">
            <p><strong>Run ID:</strong> $run_id</p>
            <p><strong>Analysis Time:</strong> $timestamp</p>
            <p><strong>Alert Count:</strong> $(length(alerts))</p>
            
            <h2>Opportunities with Significant Improvements (>20%):</h2>
    """
    
    for alert in alerts
        url = get(alert, "url", "unknown")
        change = get(alert, "change_percent", 0.0)
        current_score = get(alert, "current_score", 0.0)
        previous_score = get(alert, "previous_score", 0.0)
        forecast = get(alert, "forecast_30day", "N/A")
        confidence = get(alert, "confidence", 0.0)
        
        email_body *= """
            <div class="alert-item">
                <h3>$url</h3>
                <p><span class="metric">+$(round(change, digits=1))%</span> improvement</p>
                <p><strong>Current Score:</strong> $(round(current_score, digits=1))</p>
                <p><strong>Previous Score:</strong> $(round(previous_score, digits=1))</p>
                <p><strong>30-Day Forecast:</strong> $forecast (confidence: $(round(confidence * 100, digits=1))%)</p>
            </div>
        """
    end
    
    email_body *= """
        </div>
        
        <div class="footer">
            <p>This is an automated alert from JARVIX Trend Detection System.</p>
            <p>To configure alert settings or view detailed reports, check the reports directory.</p>
        </div>
    </body>
    </html>
    """
    
    # Save email content to file for inspection or manual sending
    data_dir = dirname(dirname(alert_file))
    email_file = joinpath(data_dir, "reports", "$(run_id)_email.html")
    open(email_file, "w") do f
        write(f, email_body)
    end
    
    println("✓ Email content generated: $email_file")
    println("📧 Email would be sent to configured recipients:")
    println("   Subject: $email_subject")
    println("   Alerts: $(length(alerts)) opportunities")
    
    # In a production environment, this would integrate with:
    # - SMTP server (using SMTPClient.jl)
    # - Email service API (SendGrid, AWS SES, etc.)
    # - Notification service (Slack, Discord, etc.)
    
    println("\n💡 To enable actual email sending, integrate with:")
    println("   - SMTP server configuration")
    println("   - Email service API (SendGrid, Mailgun, etc.)")
    println("   - Set EMAIL_RECIPIENTS environment variable")
    
    return true
end

"""
    check_and_send_alerts(data_dir::String)

Check for alert files and send email notifications.
"""
function check_and_send_alerts(data_dir::String="data")
    reports_dir = joinpath(data_dir, "reports")
    
    if !isdir(reports_dir)
        println("⚠️  Reports directory not found: $reports_dir")
        return
    end
    
    # Find all alert files
    alert_files = filter(f -> endswith(f, "_alerts.json"), readdir(reports_dir))
    
    if isempty(alert_files)
        println("✓ No pending alerts found")
        return
    end
    
    println("📬 Processing $(length(alert_files)) alert file(s)...")
    
    for alert_file in alert_files
        filepath = joinpath(reports_dir, alert_file)
        println("\n→ Processing: $alert_file")
        
        if send_email_alert(filepath)
            # Optionally rename processed alert files
            processed_file = replace(filepath, "_alerts.json" => "_alerts_sent.json")
            mv(filepath, processed_file, force=true)
            println("  ✓ Alert processed and archived")
        end
    end
end

# Main execution
if !isinteractive()
    data_dir = get(ARGS, 1, "data")
    
    println("=" ^ 60)
    println("JARVIX Email Alert System")
    println("Timestamp: $(Dates.now())")
    println("=" ^ 60)
    
    try
        check_and_send_alerts(data_dir)
        println("\n✅ Alert processing completed!")
    catch e
        println("❌ Error: $e")
        println(stacktrace(catch_backtrace()))
        exit(1)
    end
end
