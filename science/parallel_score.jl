#!/usr/bin/env julia

using Distributed
using JSON
using Statistics

"""
    parallel_score_mvp(run_id; output_dir="data", num_workers=4)

Score cleaned data in parallel using Distributed.jl.
Phase 6: Scalability enhancement for 10K+ URLs.
"""
function parallel_score_mvp(run_id; output_dir="data", num_workers=4)
    println("📊 Starting parallel scoring for run: $run_id")
    println("🚀 Launching $num_workers worker processes...")
    
    # Add worker processes if not already added
    current_workers = nworkers()
    if current_workers == 1 && num_workers > 1
        addprocs(num_workers - 1)
        println("✓ Added $(nworkers() - 1) workers (total: $(nworkers()))")
    else
        println("✓ Using existing $(nworkers()) workers")
    end
    
    # Load required packages on all workers
    @everywhere using JSON
    @everywhere using Statistics
    
    # Read clean JSONL
    clean_file = joinpath(output_dir, "clean", "$run_id.jsonl")
    if !isfile(clean_file)
        error("Clean file not found: $clean_file")
    end
    
    println("📖 Loading records from: $clean_file")
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
    
    # Define scoring function on all workers
    @everywhere function compute_score(record)
        quality = get(record, "quality_score", 0) * 0.4
        buy_keywords = get(record, "has_buy_keywords", false) ? 30.0 : 0.0
        text_len = get(record, "text_length", 0)
        normalized_len = min(100.0, (text_len / 5000.0) * 100.0) * 0.2
        errors = get(record, "errors", [])
        error_penalty = length(errors) * 5.0
        final = quality + buy_keywords + normalized_len - error_penalty
        return max(0.0, min(100.0, final))
    end
    
    # Score in parallel
    println("⚡ Computing scores in parallel...")
    start_time = time()
    
    scores = pmap(records) do record
        score = compute_score(record)
        merge(record, Dict("final_score" => score))
    end
    
    elapsed = time() - start_time
    println("✓ Scored $(length(scores)) records in $(round(elapsed, digits=2))s")
    println("  Throughput: $(round(length(scores)/elapsed, digits=1)) records/sec")
    
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
    println("  Mean:   $(round(mean(all_scores); digits=2))")
    println("  Median: $(round(median(all_scores); digits=2))")
    println("  Max:    $(round(maximum(all_scores); digits=2))")
    println("  Min:    $(round(minimum(all_scores); digits=2))")
    println("  StdDev: $(round(std(all_scores); digits=2))")
    
    return top_file
end

"""
    benchmark_parallel_scoring(num_records; num_workers=4)

Benchmark parallel scoring performance.
"""
function benchmark_parallel_scoring(num_records; num_workers=4)
    println("\n🏁 BENCHMARK: Parallel Scoring")
    println("Records: $num_records")
    println("Workers: $num_workers")
    
    # Add workers
    if nworkers() == 1 && num_workers > 1
        addprocs(num_workers - 1)
    end
    
    @everywhere using JSON
    
    # Generate synthetic records
    records = []
    for i in 1:num_records
        push!(records, Dict(
            "canonical_id" => "test_$i",
            "title" => "Test Record $i",
            "text_length" => rand(100:10000),
            "has_buy_keywords" => rand(Bool),
            "quality_score" => rand(50:100),
            "errors" => []
        ))
    end
    
    @everywhere function compute_score(record)
        quality = get(record, "quality_score", 0) * 0.4
        buy_keywords = get(record, "has_buy_keywords", false) ? 30.0 : 0.0
        text_len = get(record, "text_length", 0)
        normalized_len = min(100.0, (text_len / 5000.0) * 100.0) * 0.2
        errors = get(record, "errors", [])
        error_penalty = length(errors) * 5.0
        final = quality + buy_keywords + normalized_len - error_penalty
        return max(0.0, min(100.0, final))
    end
    
    # Benchmark serial
    println("\n📊 Serial execution...")
    start_serial = time()
    serial_scores = map(compute_score, records)
    time_serial = time() - start_serial
    
    # Benchmark parallel
    println("📊 Parallel execution...")
    start_parallel = time()
    parallel_scores = pmap(compute_score, records)
    time_parallel = time() - start_parallel
    
    # Results
    speedup = time_serial / time_parallel
    println("\n=== RESULTS ===")
    println("Serial time:   $(round(time_serial, digits=3))s")
    println("Parallel time: $(round(time_parallel, digits=3))s")
    println("Speedup:       $(round(speedup, digits=2))x")
    println("Throughput:    $(round(num_records/time_parallel, digits=1)) records/sec")
    
    if speedup > 1.5
        println("\n✅ Parallel performance GOOD (>1.5x speedup)")
    else
        println("\n⚠️  Parallel performance POOR (<1.5x speedup)")
        println("   Consider: more workers, larger dataset, or optimize compute_score")
    end
end

# Main execution
if !isinteractive()
    using Dates
    
    if length(ARGS) < 1
        println("Usage:")
        println("  julia parallel_score.jl <run_id> [output_dir] [num_workers]")
        println("  julia parallel_score.jl --benchmark <num_records> [num_workers]")
        exit(1)
    end
    
    if ARGS[1] == "--benchmark"
        num_records = get(ARGS, 2, "10000") |> x -> parse(Int, x)
        num_workers = get(ARGS, 3, "4") |> x -> parse(Int, x)
        try
            benchmark_parallel_scoring(num_records; num_workers=num_workers)
            println("\n✅ Benchmark completed successfully!")
        catch e
            println("❌ Error: $e")
            exit(1)
        end
    else
        run_id = ARGS[1]
        output_dir = get(ARGS, 2, "data")
        num_workers = get(ARGS, 3, "4") |> x -> parse(Int, x)
        
        try
            parallel_score_mvp(run_id; output_dir=output_dir, num_workers=num_workers)
            println("\n✅ Parallel scoring completed successfully!")
        catch e
            println("❌ Error: $e")
            exit(1)
        end
    end
end
