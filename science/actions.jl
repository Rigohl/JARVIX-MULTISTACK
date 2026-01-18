#!/usr/bin/env julia

using JSON
using Statistics

"""
    recommend_actions(scored_records)

Transform numeric scores into actionable recommendations (BUY/MONITOR/SKIP).

Returns a vector of records enriched with:
- `action`: Recommendation type (BUY, MONITOR, SKIP)
- `confidence`: Confidence level (0.0-1.0)
- `reason`: Human-readable explanation
- `next_step`: Suggested action to take

# Scoring Rules:
- Score > 75: BUY (95% confidence) - "Premium opportunity, contact provider"
- 50 < Score ≤ 75: MONITOR (70% confidence) - "Evaluate competence for 30 days"
- Score ≤ 50: SKIP (85% confidence) - "Low quality, no buy intent"
"""
function recommend_actions(scored_records)
    actions = []
    
    for record in scored_records
        score = get(record, "final_score", 0.0)
        
        # Determine action based on score thresholds
        action_data = if score > 75
            Dict(
                "action" => "BUY",
                "confidence" => 0.95,
                "reason" => "Premium opportunity with high quality score",
                "next_step" => "Contact provider immediately for negotiation"
            )
        elseif score > 50
            Dict(
                "action" => "MONITOR",
                "confidence" => 0.70,
                "reason" => "Medium potential, requires further evaluation",
                "next_step" => "Evaluate competence and market position for 30 days"
            )
        else
            Dict(
                "action" => "SKIP",
                "confidence" => 0.85,
                "reason" => "Low quality or insufficient buy intent signals",
                "next_step" => "Discard opportunity and focus on higher-value targets"
            )
        end
        
        # Merge action data with original record
        enriched_record = merge(record, action_data)
        push!(actions, enriched_record)
    end
    
    return actions
end

"""
    compute_action_statistics(actions)

Calculate statistics about the actions recommended.

Returns a dictionary with:
- `total_records`: Total number of records processed
- `buy_count`: Number of BUY recommendations
- `monitor_count`: Number of MONITOR recommendations
- `skip_count`: Number of SKIP recommendations
- `buy_percentage`: Percentage of BUY actions
- `avg_confidence`: Average confidence across all actions
- `avg_score_by_action`: Average score for each action type
"""
function compute_action_statistics(actions)
    total = length(actions)
    
    if total == 0
        return Dict(
            "total_records" => 0,
            "buy_count" => 0,
            "monitor_count" => 0,
            "skip_count" => 0,
            "buy_percentage" => 0.0,
            "avg_confidence" => 0.0,
            "avg_score_by_action" => Dict()
        )
    end
    
    # Count actions
    buy_count = count(r -> get(r, "action", "") == "BUY", actions)
    monitor_count = count(r -> get(r, "action", "") == "MONITOR", actions)
    skip_count = count(r -> get(r, "action", "") == "SKIP", actions)
    
    # Calculate percentages
    buy_percentage = (buy_count / total) * 100.0
    
    # Calculate average confidence
    confidences = [get(r, "confidence", 0.0) for r in actions]
    avg_confidence = mean(confidences)
    
    # Calculate average score by action type
    avg_score_by_action = Dict()
    for action_type in ["BUY", "MONITOR", "SKIP"]
        action_records = filter(r -> get(r, "action", "") == action_type, actions)
        if !isempty(action_records)
            scores = [get(r, "final_score", 0.0) for r in action_records]
            avg_score_by_action[action_type] = mean(scores)
        else
            avg_score_by_action[action_type] = 0.0
        end
    end
    
    return Dict(
        "total_records" => total,
        "buy_count" => buy_count,
        "monitor_count" => monitor_count,
        "skip_count" => skip_count,
        "buy_percentage" => round(buy_percentage; digits=2),
        "avg_confidence" => round(avg_confidence; digits=2),
        "avg_score_by_action" => avg_score_by_action
    )
end

"""
    generate_actions_report(run_id; output_dir="data")

Main function to generate actionable recommendations from scored data.

Reads scored JSONL file, applies action logic, and outputs:
1. Enriched JSONL with actions (data/actions/<run_id>.jsonl)
2. JSON summary with statistics (data/actions/<run_id>_summary.json)
"""
function generate_actions_report(run_id; output_dir="data")
    println("🎯 Generating action recommendations for run: $run_id")
    
    # Read scored JSONL
    scores_file = joinpath(output_dir, "scores", "$run_id.jsonl")
    if !isfile(scores_file)
        error("Scores file not found: $scores_file")
    end
    
    records = []
    open(scores_file) do f
        for line in eachline(f)
            if !isempty(line)
                push!(records, JSON.parse(line))
            end
        end
    end
    
    println("📋 Loaded $(length(records)) scored records")
    
    if isempty(records)
        println("⚠️  No records to process")
        return
    end
    
    # Generate action recommendations
    actions = recommend_actions(records)
    
    # Sort by score (highest first)
    sort!(actions, by = r -> get(r, "final_score", 0.0), rev=true)
    
    # Save actions JSONL
    mkpath(joinpath(output_dir, "actions"))
    actions_file = joinpath(output_dir, "actions", "$run_id.jsonl")
    open(actions_file, "w") do f
        for action in actions
            println(f, JSON.json(action))
        end
    end
    println("✓ Actions saved: $actions_file")
    
    # Compute statistics
    stats = compute_action_statistics(actions)
    
    # Save summary JSON
    summary_file = joinpath(output_dir, "actions", "$(run_id)_summary.json")
    open(summary_file, "w") do f
        JSON.print(f, Dict(
            "run_id" => run_id,
            "timestamp" => Dates.now(),
            "statistics" => stats
        ), 2)
    end
    println("✓ Summary saved: $summary_file")
    
    # Print statistics
    println("\n📊 Action Statistics:")
    println("  Total Records: $(stats["total_records"])")
    println("  BUY: $(stats["buy_count"]) ($(stats["buy_percentage"])%)")
    println("  MONITOR: $(stats["monitor_count"])")
    println("  SKIP: $(stats["skip_count"])")
    println("  Average Confidence: $(stats["avg_confidence"])")
    
    println("\n📈 Average Score by Action:")
    for (action, avg_score) in stats["avg_score_by_action"]
        println("  $action: $(round(avg_score; digits=2))")
    end
    
    return actions_file
end

# Main execution
if !isinteractive()
    using Dates
    
    if length(ARGS) < 1
        println("Usage: actions.jl <run_id> [output_dir]")
        println("\nExample: julia actions.jl mvp_test_001 data")
        exit(1)
    end
    
    run_id = ARGS[1]
    output_dir = get(ARGS, 2, "data")
    
    try
        generate_actions_report(run_id; output_dir=output_dir)
        println("\n✅ Action recommendations generated successfully!")
    catch e
        println("❌ Error: $e")
        println("\nStacktrace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
        exit(1)
    end
end
