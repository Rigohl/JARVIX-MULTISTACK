#!/usr/bin/env julia

using JSON
using Random

"""
    generate_test_scores(n_records::Int; output_dir="data", run_id="test_100")

Generate synthetic scored records for testing the actions module.

Creates records with varying scores distributed across BUY, MONITOR, and SKIP thresholds:
- ~20% with score > 75 (BUY)
- ~30% with score 50-75 (MONITOR)
- ~50% with score < 50 (SKIP)
"""
function generate_test_scores(n_records::Int; output_dir="data", run_id="test_100")
    println("📝 Generating $n_records test scored records...")
    
    Random.seed!(42)  # For reproducibility
    
    records = []
    
    for i in 1:n_records
        # Distribute scores across categories
        score_category = rand()
        
        if score_category < 0.2  # 20% BUY
            base_score = 75.0 + rand() * 25.0  # 75-100
            quality = 85.0 + rand() * 15.0     # 85-100
            has_buy_keywords = rand() < 0.8    # 80% have buy keywords
            text_length = 5000 + rand(1:95000)
        elseif score_category < 0.5  # 30% MONITOR
            base_score = 50.0 + rand() * 25.0  # 50-75
            quality = 60.0 + rand() * 30.0     # 60-90
            has_buy_keywords = rand() < 0.5    # 50% have buy keywords
            text_length = 2000 + rand(1:48000)
        else  # 50% SKIP
            base_score = 10.0 + rand() * 40.0  # 10-50
            quality = 20.0 + rand() * 60.0     # 20-80
            has_buy_keywords = rand() < 0.2    # 20% have buy keywords
            text_length = 100 + rand(1:19900)
        end
        
        # Generate some errors for variety (10% of records)
        errors = []
        if rand() < 0.1
            error_types = ["missing_title", "low_text_quality", "paywall_detected", "invalid_html"]
            push!(errors, rand(error_types))
        end
        
        # Create record
        record = Dict(
            "canonical_id" => bytes2hex(rand(UInt8, 16)),
            "title" => "Test Record $i",
            "quality_score" => round(quality; digits=1),
            "has_buy_keywords" => has_buy_keywords,
            "text_length" => text_length,
            "errors" => errors,
            "final_score" => round(base_score; digits=2)
        )
        
        push!(records, record)
    end
    
    # Sort by score (highest first)
    sort!(records, by = r -> r["final_score"], rev=true)
    
    # Ensure output directory exists
    mkpath(joinpath(output_dir, "scores"))
    
    # Save as JSONL
    output_file = joinpath(output_dir, "scores", "$run_id.jsonl")
    open(output_file, "w") do f
        for record in records
            println(f, JSON.json(record))
        end
    end
    
    println("✓ Test data saved: $output_file")
    
    # Print statistics
    high_scores = count(r -> r["final_score"] > 75, records)
    mid_scores = count(r -> r["final_score"] > 50 && r["final_score"] <= 75, records)
    low_scores = count(r -> r["final_score"] <= 50, records)
    
    println("\n📊 Score Distribution:")
    println("  > 75 (BUY): $high_scores ($(round(high_scores/n_records*100; digits=1))%)")
    println("  50-75 (MONITOR): $mid_scores ($(round(mid_scores/n_records*100; digits=1))%)")
    println("  < 50 (SKIP): $low_scores ($(round(low_scores/n_records*100; digits=1))%)")
    
    return output_file
end

# Main execution
if !isinteractive()
    if length(ARGS) < 1
        println("Usage: generate_test_data.jl <n_records> [run_id] [output_dir]")
        println("\nExample: julia generate_test_data.jl 100 test_100 data")
        exit(1)
    end
    
    n_records = parse(Int, ARGS[1])
    run_id = get(ARGS, 2, "test_$(n_records)")
    output_dir = get(ARGS, 3, "data")
    
    if n_records < 1
        println("❌ Error: n_records must be >= 1")
        exit(1)
    end
    
    try
        generate_test_scores(n_records; output_dir=output_dir, run_id=run_id)
        println("\n✅ Test data generated successfully!")
    catch e
        println("❌ Error: $e")
        exit(1)
    end
end
