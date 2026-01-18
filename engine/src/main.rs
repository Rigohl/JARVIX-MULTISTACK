mod parallel;
mod storage;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::path::PathBuf;
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;

use parallel::{ParallelConfig, ParallelDownloader};
use storage::ParquetStorage;

#[derive(Parser)]
#[command(name = "jarvix")]
#[command(about = "JARVIX v2.0 - Scalable OSINT & Scoring Engine", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Enable verbose logging
    #[arg(short, long, global = true)]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Download URLs in parallel (Phase 6: Scalability)
    Collect {
        /// Run identifier
        #[arg(long)]
        run: String,

        /// Input file with URLs (one per line)
        #[arg(long)]
        input: PathBuf,

        /// Maximum concurrent downloads
        #[arg(long, default_value = "100")]
        concurrent: usize,

        /// Timeout per request in seconds
        #[arg(long, default_value = "30")]
        timeout: u64,

        /// Output directory
        #[arg(long, default_value = "data")]
        output: PathBuf,
    },

    /// Benchmark mode: test with N URLs
    Benchmark {
        /// Number of test URLs to generate
        #[arg(long, default_value = "1000")]
        urls: usize,

        /// Maximum concurrent downloads
        #[arg(long, default_value = "100")]
        concurrent: usize,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    let level = if cli.verbose { Level::DEBUG } else { Level::INFO };
    let subscriber = FmtSubscriber::builder()
        .with_max_level(level)
        .finish();
    tracing::subscriber::set_global_default(subscriber)
        .context("Failed to set tracing subscriber")?;

    match cli.command {
        Commands::Collect {
            run,
            input,
            concurrent,
            timeout,
            output,
        } => {
            info!("Starting collection for run: {}", run);
            collect_urls(&run, &input, &output, concurrent, timeout).await?;
        }
        Commands::Benchmark { urls, concurrent } => {
            info!("Running benchmark with {} URLs", urls);
            benchmark(urls, concurrent).await?;
        }
    }

    Ok(())
}

/// Collect URLs from input file and download in parallel
async fn collect_urls(
    run_id: &str,
    input_path: &PathBuf,
    output_dir: &PathBuf,
    max_concurrent: usize,
    timeout_secs: u64,
) -> Result<()> {
    // Read URLs from input file
    let content = std::fs::read_to_string(input_path)
        .context("Failed to read input file")?;
    
    let urls: Vec<String> = content
        .lines()
        .filter(|line| !line.trim().is_empty() && !line.starts_with('#'))
        .map(|line| line.trim().to_string())
        .collect();

    info!("Loaded {} URLs from {:?}", urls.len(), input_path);

    // Configure parallel downloader
    let config = ParallelConfig {
        max_concurrent,
        timeout_secs,
        max_retries: 3,
    };

    // Download in parallel
    let downloader = ParallelDownloader::new(config)?;
    let results = downloader.download_all(urls).await;

    // Save to Parquet
    let storage = ParquetStorage::new();
    let output_path = output_dir.join("raw").join(format!("{}.parquet", run_id));
    storage.save_results(&results, &output_path)?;

    // Print summary
    let success_count = results.iter().filter(|r| r.success).count();
    let total = results.len();
    let success_rate = (success_count as f64 / total as f64) * 100.0;

    info!("Collection complete: {}/{} successful ({:.1}%)", 
          success_count, total, success_rate);

    Ok(())
}

/// Benchmark mode: generate test URLs and measure performance
async fn benchmark(url_count: usize, max_concurrent: usize) -> Result<()> {
    use std::time::Instant;

    info!("Generating {} test URLs", url_count);
    
    // Generate test URLs using httpbin for reliable testing
    let test_urls: Vec<String> = (0..url_count)
        .map(|i| format!("https://httpbin.org/delay/0?id={}", i))
        .collect();

    info!("Starting benchmark with {} concurrent workers", max_concurrent);
    let start = Instant::now();

    let config = ParallelConfig {
        max_concurrent,
        timeout_secs: 10,
        max_retries: 1,
    };

    let downloader = ParallelDownloader::new(config)?;
    let results = downloader.download_all(test_urls).await;

    let duration = start.elapsed();
    let success_count = results.iter().filter(|r| r.success).count();
    let avg_time_per_url = duration.as_millis() as f64 / url_count as f64;
    let urls_per_second = url_count as f64 / duration.as_secs_f64();

    // Print benchmark results
    println!("\n=== BENCHMARK RESULTS ===");
    println!("URLs processed:     {}", url_count);
    println!("Successful:         {} ({:.1}%)", success_count, 
             (success_count as f64 / url_count as f64) * 100.0);
    println!("Total time:         {:.2}s", duration.as_secs_f64());
    println!("Avg time per URL:   {:.1}ms", avg_time_per_url);
    println!("URLs per second:    {:.1}", urls_per_second);
    println!("Concurrent workers: {}", max_concurrent);
    
    // Check if we meet Phase 6 targets
    let target_met = avg_time_per_url < 100.0 && urls_per_second > 10.0;
    if target_met {
        println!("\n✅ Performance targets MET!");
        println!("   - Avg time < 100ms per URL: ✓");
        println!("   - Throughput > 10 URLs/s: ✓");
    } else {
        println!("\n⚠️  Performance targets NOT MET");
        if avg_time_per_url >= 100.0 {
            println!("   - Avg time < 100ms per URL: ✗ (actual: {:.1}ms)", avg_time_per_url);
        }
        if urls_per_second <= 10.0 {
            println!("   - Throughput > 10 URLs/s: ✗ (actual: {:.1})", urls_per_second);
        }
    }

    Ok(())
}
