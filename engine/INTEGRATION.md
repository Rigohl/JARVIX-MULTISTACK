# Integration Guide: External Data Enrichment

This guide shows how to integrate the enrichment engine with the existing JARVIX scoring pipeline.

## Pipeline Integration

The enrichment module fits into the existing pipeline as follows:

```
seeds.txt → 
  [collect] → HTML files →
  [curate] → JSONL (clean + invalid) →
  [score.jl] → JSON scores →
  [ENRICHMENT] → Enhanced scores →  ← NEW STEP
  [report.ts] → HTML dashboard
```

## Usage Scenarios

### Scenario 1: Post-Processing Scored Records

After Julia scoring, enrich the scores with external data:

```bash
# 1. Run existing pipeline
.\scripts\run_mvp.ps1 -RunId "production_001"

# 2. Enrich the scores
cd engine
cargo run --example batch_enrichment

# 3. Generate report with enriched data
cd ..
npx ts-node app/report.ts production_001 data
```

### Scenario 2: Real-Time Enrichment

Enrich URLs as they are collected:

```rust
use jarvix::enrich_score;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let url = "https://example.com";
    let base_score = 50.0;
    
    let enriched = enrich_score(url, base_score, "data/api_config.toml").await?;
    
    println!("Score improved from {} to {}", 
        enriched.base_score, 
        enriched.enriched_score
    );
    
    Ok(())
}
```

### Scenario 3: Batch Enrichment Script

Create a custom enrichment script for your specific needs:

```rust
use jarvix::{EnrichmentEngine, EnrichmentConfig};
use std::fs;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load config
    let config: EnrichmentConfig = toml::from_str(
        &fs::read_to_string("data/api_config.toml")?
    )?;
    
    let engine = EnrichmentEngine::new(config)?;
    
    // Load scored records
    let input_path = "data/scores/run_001.jsonl";
    let output_path = "data/scores/run_001_enriched.jsonl";
    
    let content = fs::read_to_string(input_path)?;
    let mut enriched_records = Vec::new();
    
    for line in content.lines() {
        let record: serde_json::Value = serde_json::from_str(line)?;
        let url = record["url"].as_str().unwrap();
        let score = record["final_score"].as_f64().unwrap();
        
        if let Ok(enriched) = engine.enrich_url(url, score).await {
            let mut new_record = record.clone();
            new_record["enriched_score"] = serde_json::json!(enriched.enriched_score);
            new_record["site_type"] = serde_json::json!(enriched.site_type);
            new_record["adjustments"] = serde_json::json!(enriched.adjustments);
            enriched_records.push(new_record);
        }
    }
    
    // Write enriched records
    let output: Vec<String> = enriched_records
        .iter()
        .map(|r| serde_json::to_string(r).unwrap())
        .collect();
    
    fs::write(output_path, output.join("\n"))?;
    
    Ok(())
}
```

## Julia Integration

You can call the enrichment engine from Julia using the Julia-Rust FFI or by creating a command-line interface:

### Option 1: CLI Integration

Create a CLI tool:

```rust
// engine/src/main.rs
use jarvix::enrich_score;
use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(short, long)]
    url: String,
    
    #[arg(short, long)]
    score: f64,
    
    #[arg(short, long, default_value = "data/api_config.toml")]
    config: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let enriched = enrich_score(&args.url, args.score, &args.config).await?;
    
    // Output as JSON for Julia to parse
    println!("{}", serde_json::to_string(&enriched)?);
    
    Ok(())
}
```

Then call from Julia:

```julia
using JSON

function enrich_score(url::String, base_score::Float64)
    cmd = `./engine/target/release/jarvix enrich --url $url --score $base_score`
    output = read(cmd, String)
    return JSON.parse(output)
end

# Usage
enriched = enrich_score("https://example.com", 50.0)
println("Enriched score: ", enriched["enriched_score"])
```

### Option 2: HTTP API

Create a small HTTP server:

```rust
use axum::{Json, Router, routing::post};
use serde::{Deserialize, Serialize};
use jarvix::enrich_score;

#[derive(Deserialize)]
struct EnrichRequest {
    url: String,
    base_score: f64,
}

async fn enrich_handler(
    Json(req): Json<EnrichRequest>,
) -> Json<serde_json::Value> {
    match enrich_score(&req.url, req.base_score, "data/api_config.toml").await {
        Ok(enriched) => Json(serde_json::json!(enriched)),
        Err(e) => Json(serde_json::json!({"error": e.to_string()})),
    }
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/enrich", post(enrich_handler));
    
    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```

Then call from Julia:

```julia
using HTTP, JSON

function enrich_score(url::String, base_score::Float64)
    response = HTTP.post(
        "http://localhost:3000/enrich",
        ["Content-Type" => "application/json"],
        JSON.json(Dict("url" => url, "base_score" => base_score))
    )
    return JSON.parse(String(response.body))
end
```

## PowerShell Integration

Add enrichment step to the PowerShell orchestrator:

```powershell
# scripts/run_mvp_with_enrichment.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$RunId
)

# Existing pipeline
& $exe collect --run $RunId --input data/seeds.txt
& $exe curate --run $RunId
julia science/score.jl $RunId data

# NEW: Enrichment step
Write-Host "Enriching scores with external data..." -ForegroundColor Cyan
Push-Location engine
cargo run --release --example batch_enrichment
Pop-Location

# Report generation
npx ts-node app/report.ts $RunId data
```

## TypeScript Report Integration

Update the report generator to show enrichment data:

```typescript
interface EnrichedScore {
    url: string;
    base_score: number;
    enriched_score: number;
    site_type: string;
    adjustments: Array<{
        source: string;
        adjustment: number;
        reason: string;
    }>;
}

// Load enriched scores
const enrichedScores = loadEnrichedScores(runId);

// Display in report
for (const score of enrichedScores) {
    console.log(`${score.url}: ${score.base_score} → ${score.enriched_score}`);
    console.log(`  Site Type: ${score.site_type}`);
    for (const adj of score.adjustments) {
        console.log(`  ${adj.source}: ${adj.adjustment}% - ${adj.reason}`);
    }
}
```

## Configuration

### Environment-Specific Configs

Create different configs for different environments:

```
data/
  api_config.toml          # Default/production
  api_config.dev.toml      # Development (more verbose)
  api_config.test.toml     # Testing (mocked APIs)
```

### API Key Management

Store API keys securely:

```toml
# data/api_config.toml
[crunchbase]
api_key = "${CRUNCHBASE_API_KEY}"  # Will be read from environment variable
```

Or use a separate secrets file:

```toml
# data/api_secrets.toml (add to .gitignore)
crunchbase_api_key = "your-secret-key-here"
```

## Performance Tuning

### Parallel Processing

For large batches, use parallel processing:

```rust
use futures::stream::{self, StreamExt};

let urls = vec![/* ... */];
let results: Vec<_> = stream::iter(urls)
    .map(|(url, score)| async move {
        engine.enrich_url(&url, score).await
    })
    .buffer_unordered(10)  // Process 10 URLs concurrently
    .collect()
    .await;
```

### Cache Warming

Pre-populate cache for known URLs:

```bash
# Warm up the cache before processing
cargo run --example cache_warmup -- --urls data/seeds.txt
```

### Rate Limit Optimization

Adjust rate limits based on your API tiers:

```toml
[google_trends]
rate_limit_per_hour = 200  # Increase if you have premium access
```

## Monitoring

### Logging

Enable detailed logging:

```rust
use tracing_subscriber;

tracing_subscriber::fmt::init();

// Now all enrichment operations will be logged
```

### Metrics

Track enrichment metrics:

```rust
struct EnrichmentMetrics {
    total_processed: u64,
    total_enriched: u64,
    cache_hits: u64,
    cache_misses: u64,
    api_calls: HashMap<String, u64>,
}
```

## Troubleshooting

### Common Issues

1. **Rate limit exceeded**: Reduce concurrent requests or increase cache TTL
2. **API timeout**: Increase timeout_seconds in config
3. **Cache misses**: Check database permissions and disk space
4. **Whois command not found**: Install whois: `apt-get install whois`

### Debug Mode

Run with verbose output:

```bash
RUST_LOG=debug cargo run --example batch_enrichment
```

## Next Steps

1. Add more enrichment providers (Trustpilot, Crunchbase)
2. Implement Redis caching for distributed systems
3. Create web dashboard for enrichment monitoring
4. Add machine learning-based enrichment predictions
