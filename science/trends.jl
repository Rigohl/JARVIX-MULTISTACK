#!/usr/bin/env julia

using JSON
using Statistics
using Dates
using SQLite

"""
    detect_trends(url::String; history_days::Int=30, db_path::String="data/jarvix.db")

Detect temporal trends for a given URL by analyzing historical score data.

Returns a Dict with:
- trend_status: "NEW", "IMPROVED", "DECLINED", or "STABLE"
- current_score: Most recent score
- previous_score: Score from 7 days ago (if available)
- change_percent: Percentage change in score
- forecast_30day: Predicted score in 30 days
- confidence: Confidence level of the trend (0-1)
"""
function detect_trends(url::String; history_days::Int=30, db_path::String="data/jarvix.db")
    if !isfile(db_path)
        error("Database not found: $db_path")
    end
    
    db = SQLite.DB(db_path)
    
    # Query historical data for this URL
    query = """
        SELECT score_date, final_score, quality_score, text_length, has_buy_keywords
        FROM opportunity_history
        WHERE url = ?
        ORDER BY score_date DESC
        LIMIT ?
    """
    
    result = SQLite.DBInterface.execute(db, query, [url, history_days]) |> collect
    
    if isempty(result)
        return Dict(
            "url" => url,
            "trend_status" => "NEW",
            "current_score" => nothing,
            "previous_score" => nothing,
            "change_percent" => 0.0,
            "forecast_30day" => nothing,
            "confidence" => 0.0,
            "message" => "No historical data available"
        )
    end
    
    # Extract scores and dates
    dates = [row.score_date for row in result]
    scores = [row.final_score for row in result]
    
    current_score = scores[1]
    
    # Find score from 7 days ago
    target_date = dates[1] - Day(7)
    seven_day_score = nothing
    
    for (i, d) in enumerate(dates)
        if abs(Dates.value(d - target_date)) <= 1  # Within 1 day tolerance
            seven_day_score = scores[i]
            break
        end
    end
    
    # Calculate trend status
    trend_status = "STABLE"
    change_percent = 0.0
    
    if isnothing(seven_day_score)
        # Less than 7 days of data
        if length(scores) == 1
            trend_status = "NEW"
        else
            # Use oldest available score for comparison
            seven_day_score = scores[end]
            change_percent = ((current_score - seven_day_score) / seven_day_score) * 100
            trend_status = classify_trend(change_percent)
        end
    else
        change_percent = ((current_score - seven_day_score) / seven_day_score) * 100
        trend_status = classify_trend(change_percent)
    end
    
    # Calculate 30-day forecast using linear regression
    forecast, confidence = forecast_30day(dates, scores)
    
    return Dict(
        "url" => url,
        "trend_status" => trend_status,
        "current_score" => current_score,
        "previous_score" => seven_day_score,
        "change_percent" => round(change_percent, digits=2),
        "forecast_30day" => forecast,
        "confidence" => round(confidence, digits=3),
        "data_points" => length(scores),
        "analysis_date" => Dates.now()
    )
end

"""
    classify_trend(change_percent::Float64)

Classify trend based on percentage change:
- IMPROVED: > 10%
- DECLINED: < -10%
- STABLE: between -10% and 10%
"""
function classify_trend(change_percent::Float64)
    if change_percent > 10.0
        return "IMPROVED"
    elseif change_percent < -10.0
        return "DECLINED"
    else
        return "STABLE"
    end
end

"""
    forecast_30day(dates, scores)

Forecast score 30 days from now using simple linear regression.
Returns (forecast_score, confidence)
"""
function forecast_30day(dates, scores)
    if length(scores) < 2
        return (nothing, 0.0)
    end
    
    # Convert dates to days from first date
    first_date = dates[end]
    x = [Dates.value(d - first_date) for d in dates]
    y = scores
    
    # Simple linear regression: y = mx + b
    n = length(x)
    mean_x = mean(x)
    mean_y = mean(y)
    
    # Calculate slope (m)
    numerator = sum((x[i] - mean_x) * (y[i] - mean_y) for i in 1:n)
    denominator = sum((x[i] - mean_x)^2 for i in 1:n)
    
    if denominator == 0
        return (mean_y, 0.5)
    end
    
    m = numerator / denominator
    b = mean_y - m * mean_x
    
    # Predict 30 days from most recent date
    days_ahead = x[1] + 30
    forecast = m * days_ahead + b
    forecast = max(0.0, min(100.0, forecast))  # Clamp between 0-100
    
    # Calculate R² for confidence
    ss_tot = sum((y[i] - mean_y)^2 for i in 1:n)
    ss_res = sum((y[i] - (m * x[i] + b))^2 for i in 1:n)
    r_squared = ss_tot > 0 ? 1 - (ss_res / ss_tot) : 0.0
    confidence = max(0.0, min(1.0, r_squared))
    
    return (round(forecast, digits=2), confidence)
end

"""
    store_score_history(db_path, url, score_data)

Store a score record in opportunity_history table.
"""
function store_score_history(db_path::String, url::String, score_data::Dict)
    db = SQLite.DB(db_path)
    
    # Get current date
    current_date = Dates.today()
    
    # Extract fields from score_data
    final_score = get(score_data, "final_score", 0.0)
    quality_score = get(score_data, "quality_score", 0.0)
    text_length = get(score_data, "text_length", 0)
    has_buy_keywords = get(score_data, "has_buy_keywords", false) ? 1 : 0
    
    # Insert or replace
    query = """
        INSERT OR REPLACE INTO opportunity_history 
        (url, score_date, final_score, quality_score, text_length, has_buy_keywords, status)
        VALUES (?, ?, ?, ?, ?, ?, 'NEW')
    """
    
    SQLite.DBInterface.execute(db, query, [url, current_date, final_score, quality_score, text_length, has_buy_keywords])
    
    return true
end

"""
    analyze_trends_batch(run_id; output_dir="data", db_path="data/jarvix.db", history_days=30)

Analyze trends for all URLs in a scored run and generate trend report.
"""
function analyze_trends_batch(run_id::String; output_dir::String="data", db_path::String="data/jarvix.db", history_days::Int=30)
    println("📊 Starting trend analysis for run: $run_id")
    
    # Read scores file
    scores_file = joinpath(output_dir, "scores", "$run_id.jsonl")
    if !isfile(scores_file)
        error("Scores file not found: $scores_file")
    end
    
    # Initialize database if needed
    init_database(db_path)
    
    # Load scored records
    records = []
    open(scores_file) do f
        for line in eachline(f)
            if !isempty(line)
                push!(records, JSON.parse(line))
            end
        end
    end
    
    println("🔍 Loaded $(length(records)) scored records")
    
    if isempty(records)
        println("⚠️  No records to analyze")
        return
    end
    
    # Store current scores in history
    for record in records
        url = get(record, "url", get(record, "canonical_id", "unknown"))
        store_score_history(db_path, url, record)
    end
    
    # Analyze trends for each URL
    trends = []
    improved_count = 0
    
    for record in records
        url = get(record, "url", get(record, "canonical_id", "unknown"))
        trend = detect_trends(url; history_days=history_days, db_path=db_path)
        
        if trend["trend_status"] == "IMPROVED" && !isnothing(trend["change_percent"]) && trend["change_percent"] > 20
            improved_count += 1
        end
        
        push!(trends, trend)
    end
    
    # Sort by change_percent (descending)
    sort!(trends, by = t -> get(t, "change_percent", 0.0), rev=true)
    
    # Save trends as JSON
    mkpath(joinpath(output_dir, "reports"))
    trends_json = joinpath(output_dir, "reports", "$(run_id)_trends.json")
    open(trends_json, "w") do f
        JSON.print(f, Dict(
            "run_id" => run_id,
            "analysis_date" => Dates.now(),
            "total_urls" => length(trends),
            "improved_count" => improved_count,
            "trends" => trends
        ), 2)
    end
    println("✓ Trends JSON saved: $trends_json")
    
    # Save trends as CSV
    trends_csv = joinpath(output_dir, "reports", "$(run_id)_trends.csv")
    open(trends_csv, "w") do f
        # Header
        println(f, "url,trend_status,current_score,previous_score,change_percent,forecast_30day,confidence,data_points")
        # Data
        for trend in trends
            println(f, join([
                get(trend, "url", ""),
                get(trend, "trend_status", ""),
                get(trend, "current_score", ""),
                get(trend, "previous_score", ""),
                get(trend, "change_percent", ""),
                get(trend, "forecast_30day", ""),
                get(trend, "confidence", ""),
                get(trend, "data_points", "")
            ], ","))
        end
    end
    println("✓ Trends CSV saved: $trends_csv")
    
    # Print summary
    println("\n📈 Trend Analysis Summary:")
    println("  Total URLs: $(length(trends))")
    println("  NEW: $(count(t -> t["trend_status"] == "NEW", trends))")
    println("  IMPROVED: $(count(t -> t["trend_status"] == "IMPROVED", trends))")
    println("  DECLINED: $(count(t -> t["trend_status"] == "DECLINED", trends))")
    println("  STABLE: $(count(t -> t["trend_status"] == "STABLE", trends))")
    println("  Significant improvements (>20%): $improved_count")
    
    return trends_json
end

"""
    init_database(db_path)

Initialize database with schema if it doesn't exist.
"""
function init_database(db_path::String)
    # Create directory if needed
    mkpath(dirname(db_path))
    
    # Create or open database
    db = SQLite.DB(db_path)
    
    # Create opportunity_history table if it doesn't exist
    schema = """
        CREATE TABLE IF NOT EXISTS opportunity_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT NOT NULL,
            score_date DATE NOT NULL,
            final_score REAL NOT NULL,
            quality_score REAL,
            text_length INTEGER,
            has_buy_keywords INTEGER,
            buy_keywords_count INTEGER DEFAULT 0,
            status TEXT CHECK(status IN ('NEW', 'IMPROVED', 'DECLINED', 'STABLE')) DEFAULT 'NEW',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(url, score_date)
        );
        
        CREATE INDEX IF NOT EXISTS idx_opportunity_history_url ON opportunity_history(url);
        CREATE INDEX IF NOT EXISTS idx_opportunity_history_date ON opportunity_history(score_date);
        CREATE INDEX IF NOT EXISTS idx_opportunity_history_status ON opportunity_history(status);
    """
    
    SQLite.DBInterface.execute(db, schema)
    
    return db
end

# Main execution
if !isinteractive()
    if length(ARGS) < 1
        println("Usage: trends.jl <run_id> [output_dir] [db_path] [history_days]")
        println("\nExamples:")
        println("  trends.jl demo_001")
        println("  trends.jl demo_001 data")
        println("  trends.jl demo_001 data data/jarvix.db 30")
        exit(1)
    end
    
    run_id = ARGS[1]
    output_dir = get(ARGS, 2, "data")
    db_path = get(ARGS, 3, "data/jarvix.db")
    history_days = parse(Int, get(ARGS, 4, "30"))
    
    try
        analyze_trends_batch(run_id; output_dir=output_dir, db_path=db_path, history_days=history_days)
        println("\n✅ Trend analysis completed successfully!")
    catch e
        println("❌ Error: $e")
        println(stacktrace(catch_backtrace()))
        exit(1)
    end
end
