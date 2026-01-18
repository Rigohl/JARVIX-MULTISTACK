use anyhow::Result;
use clap::{Parser, Subcommand};
use jarvix::{enrich_score, EnrichmentConfig, EnrichmentEngine};
use serde_json;
use std::fs;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "jarvix-enrichment")]
#[command(about = "JARVIX External Data Enrichment CLI", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Enrich a single URL
    Enrich {
        /// URL to enrich
        #[arg(short, long)]
        url: String,

        /// Base score for the URL
        #[arg(short, long)]
        score: f64,

        /// Path to config file
        #[arg(short, long, default_value = "data/api_config.toml")]
        config: PathBuf,

        /// Output format: json or text
        #[arg(short, long, default_value = "text")]
        format: String,
    },

    /// Enrich a batch of scored records from JSONL file
    Batch {
        /// Input JSONL file with scored records
        #[arg(short, long)]
        input: PathBuf,

        /// Output JSONL file for enriched records
        #[arg(short, long)]
        output: PathBuf,

        /// Path to config file
        #[arg(short, long, default_value = "data/api_config.toml")]
        config: PathBuf,

        /// Show progress during processing
        #[arg(short, long, default_value = "true")]
        verbose: bool,
    },

    /// Initialize or reset the enrichment cache
    InitCache {
        /// Path to config file
        #[arg(short, long, default_value = "data/api_config.toml")]
        config: PathBuf,
    },

    /// Show cache statistics
    CacheStats {
        /// Path to config file
        #[arg(short, long, default_value = "data/api_config.toml")]
        config: PathBuf,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Enrich {
            url,
            score,
            config,
            format,
        } => {
            let config_path = config.to_str()
                .ok_or_else(|| anyhow::anyhow!("Invalid config path"))?;
            let enriched = enrich_score(&url, score, config_path).await?;

            match format.as_str() {
                "json" => {
                    println!("{}", serde_json::to_string_pretty(&enriched)?);
                }
                _ => {
                    println!("URL: {}", enriched.url);
                    println!("Base Score: {:.2}", enriched.base_score);
                    println!("Enriched Score: {:.2}", enriched.enriched_score);
                    println!(
                        "Improvement: {:+.2}%",
                        enriched.enriched_score - enriched.base_score
                    );
                    println!("Site Type: {:?}", enriched.site_type);

                    if !enriched.adjustments.is_empty() {
                        println!("\nAdjustments:");
                        for adj in enriched.adjustments {
                            println!(
                                "  {} {:+.1}%: {}",
                                adj.source, adj.adjustment, adj.reason
                            );
                        }
                    }

                    if let Some(trending) = enriched.enrichment_data.is_trending {
                        println!("\nTrending: {}", trending);
                    }
                    if let Some(shopify) = enriched.enrichment_data.is_shopify {
                        println!("Shopify Store: {}", shopify);
                    }
                    if let Some(age) = enriched.enrichment_data.domain_age_years {
                        println!("Domain Age: {:.1} years", age);
                    }
                }
            }
        }

        Commands::Batch {
            input,
            output,
            config,
            verbose,
        } => {
            let config_content = fs::read_to_string(&config)?;
            let engine_config: EnrichmentConfig = toml::from_str(&config_content)?;
            let engine = EnrichmentEngine::new(engine_config)?;

            let content = fs::read_to_string(&input)?;
            let lines: Vec<&str> = content.lines().collect();
            let total = lines.len();

            if verbose {
                println!("Processing {} records from {:?}", total, input);
            }

            let mut enriched_records = Vec::new();
            let mut success_count = 0;

            for (i, line) in lines.iter().enumerate() {
                if let Ok(record) = serde_json::from_str::<serde_json::Value>(line) {
                    if let (Some(url), Some(score)) = (
                        record.get("url").and_then(|v| v.as_str()),
                        record.get("final_score").and_then(|v| v.as_f64()),
                    ) {
                        match engine.enrich_url(url, score).await {
                            Ok(enriched) => {
                                let mut new_record = record.clone();
                                new_record["enriched_score"] =
                                    serde_json::json!(enriched.enriched_score);
                                new_record["site_type"] = serde_json::json!(enriched.site_type);
                                new_record["enrichment_adjustments"] =
                                    serde_json::json!(enriched.adjustments);
                                new_record["enrichment_data"] =
                                    serde_json::json!(enriched.enrichment_data);

                                enriched_records.push(new_record);
                                success_count += 1;

                                if verbose && (i + 1) % 10 == 0 {
                                    println!("Processed {}/{} records", i + 1, total);
                                }
                            }
                            Err(e) => {
                                if verbose {
                                    eprintln!("Error enriching {}: {}", url, e);
                                }
                                enriched_records.push(record.clone());
                            }
                        }
                    }
                }
            }

            // Write output
            let output_lines: Vec<String> = enriched_records
                .iter()
                .map(|r| serde_json::to_string(r))
                .collect::<Result<Vec<String>, _>>()?;

            fs::write(&output, output_lines.join("\n"))?;

            if verbose {
                println!("\n=== Summary ===");
                println!("Total records: {}", total);
                println!("Successfully enriched: {}", success_count);
                println!("Output written to: {:?}", output);
            }
        }

        Commands::InitCache { config } => {
            let config_content = fs::read_to_string(&config)?;
            let engine_config: EnrichmentConfig = toml::from_str(&config_content)?;

            use rusqlite::Connection;
            let conn = Connection::open(&engine_config.cache.database_path)?;

            conn.execute("DROP TABLE IF EXISTS enrichment_cache", [])?;
            conn.execute(
                "CREATE TABLE enrichment_cache (
                    url_hash TEXT PRIMARY KEY,
                    url TEXT NOT NULL,
                    enrichment_data TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )",
                [],
            )?;
            conn.execute(
                "CREATE INDEX idx_created_at ON enrichment_cache(created_at)",
                [],
            )?;

            println!("Cache initialized successfully at: {}", engine_config.cache.database_path);
        }

        Commands::CacheStats { config } => {
            let config_content = fs::read_to_string(&config)?;
            let engine_config: EnrichmentConfig = toml::from_str(&config_content)?;

            use rusqlite::Connection;
            let conn = Connection::open(&engine_config.cache.database_path)?;

            let count: i64 = conn.query_row(
                "SELECT COUNT(*) FROM enrichment_cache",
                [],
                |row| row.get(0),
            )?;

            println!("=== Cache Statistics ===");
            println!("Database: {}", engine_config.cache.database_path);
            println!("Total cached entries: {}", count);
            println!("Cache TTL: {} hours", engine_config.cache.cache_ttl_hours);

            if count > 0 {
                let oldest: String = conn.query_row(
                    "SELECT created_at FROM enrichment_cache ORDER BY created_at ASC LIMIT 1",
                    [],
                    |row| row.get(0),
                )?;

                let newest: String = conn.query_row(
                    "SELECT created_at FROM enrichment_cache ORDER BY created_at DESC LIMIT 1",
                    [],
                    |row| row.get(0),
                )?;

                println!("Oldest entry: {}", oldest);
                println!("Newest entry: {}", newest);
            }
        }
    }

    Ok(())
}
