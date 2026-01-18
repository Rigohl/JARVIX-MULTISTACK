use jarvix::{enrich_score};
use std::time::Instant;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("JARVIX Enrichment Performance Benchmark");
    println!("========================================\n");

    let config_path = "data/api_config.toml";
    
    // Generate 100 test URLs
    let test_urls: Vec<(String, f64)> = (1..=100)
        .map(|i| {
            let url = format!("https://example{}.com", i);
            let base_score = 40.0 + (i % 30) as f64;
            (url, base_score)
        })
        .collect();

    println!("Processing {} URLs...", test_urls.len());
    let start = Instant::now();
    
    let mut success_count = 0;
    let mut total_adjustment = 0.0;

    for (url, base_score) in test_urls {
        match enrich_score(&url, base_score, config_path).await {
            Ok(enriched) => {
                success_count += 1;
                let adjustment = enriched.enriched_score - enriched.base_score;
                total_adjustment += adjustment;
            }
            Err(e) => {
                eprintln!("Error processing {}: {}", url, e);
            }
        }
    }

    let elapsed = start.elapsed();
    let elapsed_secs = elapsed.as_secs_f64();

    println!("\n=== Results ===");
    println!("Total URLs processed: {}", success_count);
    println!("Time elapsed: {:.2}s", elapsed_secs);
    println!("Average time per URL: {:.3}s", elapsed_secs / success_count as f64);
    println!("URLs per second: {:.2}", success_count as f64 / elapsed_secs);
    println!("Average adjustment: {:.2}%", total_adjustment / success_count as f64);
    
    if elapsed_secs < 30.0 {
        println!("\n✓ Performance target met! ({:.2}s < 30s)", elapsed_secs);
    } else {
        println!("\n✗ Performance target not met ({:.2}s >= 30s)", elapsed_secs);
    }

    Ok(())
}
