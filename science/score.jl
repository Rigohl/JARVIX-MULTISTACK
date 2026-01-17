#!/usr/bin/env julia

using JSON
using Statistics

"""
    score_mvp(run_id; output_dir="data")

Score cleaned data and identify top opportunities.
"""
function score_mvp(run_id; output_dir="data")
    println("📊 Starting scoring for run: $run_id")
    
    # Read clean JSONL
    clean_file = joinpath(output_dir, "clean", "$run_id.jsonl")
    if !isfile(clean_file)
        error("Clean file not found: $clean_file")
    end
    
    records = []
    open(clean_file) do f
        for line in eachline(f)
            if !isempty(line)
                push!(records, JSON.parse(line))
            end
        end
    end
    
    println("🔍 Loaded $(length(records)) clean records")
    
    if isempty(records)
        println("⚠️  No records to score")
        return
    end
    
    # Compute scores
    scores = []
    for record in records
        score = compute_score(record)
        record["final_score"] = score
        push!(scores, record)
    end
    
    # Sort by score
    sort!(scores, by = r -> r["final_score"], rev=true)
    
    # Save scores JSONL
    mkpath(joinpath(output_dir, "scores"))
    scores_file = joinpath(output_dir, "scores", "$run_id.jsonl")
    open(scores_file, "w") do f
        for record in scores
            println(f, JSON.json(record))
        end
    end
    println("✓ Scores saved: $scores_file")
    
    # Top 10
    top_10 = scores[1:min(10, length(scores))]
    
    # Save top JSON
    mkpath(joinpath(output_dir, "top"))
    top_file = joinpath(output_dir, "top", "$run_id.json")
    open(top_file, "w") do f
        JSON.print(f, Dict(
            "run_id" => run_id,
            "count" => length(top_10),
            "timestamp" => Dates.now(),
            "items" => top_10
        ))
    end
    println("✓ Top 10 saved: $top_file")
    
    # Stats
    all_scores = [r["final_score"] for r in scores]
    println("\n📈 Score Statistics:")
    println("  Mean: $(round(mean(all_scores); digits=2))")
    println("  Median: $(round(median(all_scores); digits=2))")
    println("  Max: $(round(maximum(all_scores); digits=2))")
    println("  Min: $(round(minimum(all_scores); digits=2))")
    
    return top_file
end

"""
    compute_score(record)

Compute a simple score based on:
- quality_score (40%)
- buy_keywords (30%)
- text_length normalized (20%)
- error penalties (10%)
"""
function compute_score(record)
    quality = get(record, "quality_score", 0) * 0.4
    
    buy_keywords = get(record, "has_buy_keywords", false) ? 30.0 : 0.0
    
    text_len = get(record, "text_length", 0)
    normalized_len = min(100.0, (text_len / 5000.0) * 100.0) * 0.2
    
    errors = get(record, "errors", [])
    error_penalty = length(errors) * 5.0
    
    final = quality + buy_keywords + normalized_len - error_penalty
    return max(0.0, min(100.0, final))
end

# Main execution
if !isinteractive()
    using Dates
    
    if length(ARGS) < 1
        println("Usage: score.jl <run_id> [output_dir]")
        exit(1)
    end
    
    run_id = ARGS[1]
    output_dir = get(ARGS, 2, "data")
    
    try
        score_mvp(run_id; output_dir=output_dir)
        println("\n✅ Scoring completed successfully!")
    catch e
        println("❌ Error: $e")
        exit(1)
    end
end
