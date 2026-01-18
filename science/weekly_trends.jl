#!/usr/bin/env julia
# Weekly Trend Re-Analysis Script
# To be run as a cron job every 7 days

using Dates

"""
    run_weekly_trend_analysis()

Re-analyze all URLs from the most recent run and detect trends.
This should be scheduled to run weekly via cron.
"""
function run_weekly_trend_analysis()
    println("=" ^ 60)
    println("JARVIX Weekly Trend Analysis")
    println("Timestamp: $(Dates.now())")
    println("=" ^ 60)
    
    # Get the most recent run_id from data directory
    data_dir = joinpath(@__DIR__, "..", "data")
    scores_dir = joinpath(data_dir, "scores")
    
    if !isdir(scores_dir)
        println("❌ Scores directory not found: $scores_dir")
        exit(1)
    end
    
    # Find all score files
    score_files = filter(f -> endswith(f, ".jsonl"), readdir(scores_dir))
    
    if isempty(score_files)
        println("⚠️  No score files found. Nothing to analyze.")
        exit(0)
    end
    
    # Get most recent file by modification time
    latest_file = ""
    latest_time = DateTime(0)
    
    for file in score_files
        filepath = joinpath(scores_dir, file)
        mtime = Dates.unix2datetime(stat(filepath).mtime)
        if mtime > latest_time
            latest_time = mtime
            latest_file = file
        end
    end
    
    # Extract run_id from filename (remove .jsonl extension)
    run_id = replace(latest_file, ".jsonl" => "")
    
    println("\n📊 Analyzing run: $run_id")
    println("   File modified: $latest_time")
    
    # Run trend analysis
    trends_script = joinpath(@__DIR__, "trends.jl")
    db_path = joinpath(data_dir, "jarvix.db")
    
    cmd = `julia $trends_script $run_id $data_dir $db_path 30`
    
    try
        run(cmd)
        println("\n✅ Weekly trend analysis completed successfully!")
        
        # Check if there are significant improvements (>20%) for email alerts
        check_for_alerts(run_id, data_dir)
    catch e
        println("\n❌ Error during trend analysis: $e")
        exit(1)
    end
end

"""
    check_for_alerts(run_id, data_dir)

Check if any URLs have significant improvements (>20%) and prepare alert info.
"""
function check_for_alerts(run_id::String, data_dir::String)
    using JSON
    
    trends_file = joinpath(data_dir, "reports", "$(run_id)_trends.json")
    
    if !isfile(trends_file)
        println("⚠️  Trends file not found: $trends_file")
        return
    end
    
    trends_data = JSON.parsefile(trends_file)
    trends = get(trends_data, "trends", [])
    
    # Find significant improvements
    alerts = filter(t -> 
        get(t, "trend_status", "") == "IMPROVED" && 
        !isnothing(get(t, "change_percent", nothing)) && 
        get(t, "change_percent", 0.0) > 20.0,
        trends
    )
    
    if !isempty(alerts)
        println("\n🔔 Alert: $(length(alerts)) URL(s) with significant improvements (>20%):")
        for alert in alerts
            println("   - $(get(alert, "url", "unknown")): +$(get(alert, "change_percent", 0))%")
        end
        
        # Create alert file for email system to pick up
        alert_file = joinpath(data_dir, "reports", "$(run_id)_alerts.json")
        open(alert_file, "w") do f
            JSON.print(f, Dict(
                "timestamp" => Dates.now(),
                "run_id" => run_id,
                "alert_count" => length(alerts),
                "alerts" => alerts
            ), 2)
        end
        println("   Alert file created: $alert_file")
    else
        println("\n✓ No significant improvements detected (>20% threshold)")
    end
end

# Main execution
if !isinteractive()
    try
        run_weekly_trend_analysis()
    catch e
        println("❌ Fatal error: $e")
        println(stacktrace(catch_backtrace()))
        exit(1)
    end
end
