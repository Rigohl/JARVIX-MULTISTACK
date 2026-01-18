use jarvix::{EnrichmentEngine, EnrichmentConfig};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ScoredRecord {
    url: String,
    final_score: f64,
    quality_score: f64,
    buy_keywords_count: i32,
    text_length: i32,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("JARVIX Batch Enrichment");
    println!("=======================\n");

    // Load configuration
    let config_path = "data/api_config.toml";
    let config_content = fs::read_to_string(config_path)?;
    let config: EnrichmentConfig = toml::from_str(&config_content)?;

    // Create enrichment engine
    let engine = EnrichmentEngine::new(config)?;

    // Example: Load scored records from JSONL file
    let scores_path = "data/scores/demo_001.jsonl";
    
    if !Path::new(scores_path).exists() {
        println!("Note: {} not found, using example data", scores_path);
        
        // Create example scored records
        let example_records = vec![
            ScoredRecord {
                url: "https://www.shopify.com".to_string(),
                final_score: 58.0,
                quality_score: 85.0,
                buy_keywords_count: 5,
                text_length: 2500,
            },
            ScoredRecord {
                url: "https://techcrunch.com".to_string(),
                final_score: 52.0,
                quality_score: 80.0,
                buy_keywords_count: 3,
                text_length: 3000,
            },
            ScoredRecord {
                url: "https://example.com".to_string(),
                final_score: 45.0,
                quality_score: 70.0,
                buy_keywords_count: 2,
                text_length: 1500,
            },
        ];

        println!("Processing {} scored records...\n", example_records.len());

        for record in example_records {
            println!("URL: {}", record.url);
            println!("  Original score: {:.1}", record.final_score);
            
            match engine.enrich_url(&record.url, record.final_score).await {
                Ok(enriched) => {
                    println!("  Enriched score: {:.1}", enriched.enriched_score);
                    println!("  Improvement: {:+.1}%", enriched.enriched_score - record.final_score);
                    println!("  Site type: {:?}", enriched.site_type);
                    
                    if !enriched.adjustments.is_empty() {
                        println!("  Adjustments:");
                        for adj in enriched.adjustments {
                            println!("    - {}: {:+.1}% ({})", 
                                adj.source, 
                                adj.adjustment, 
                                adj.reason
                            );
                        }
                    }
                }
                Err(e) => {
                    println!("  Error: {}", e);
                }
            }
            println!();
        }
    } else {
        // Load actual scored records from file
        let content = fs::read_to_string(scores_path)?;
        let records: Vec<ScoredRecord> = content
            .lines()
            .filter_map(|line| serde_json::from_str(line).ok())
            .collect();

        println!("Loaded {} records from {}", records.len(), scores_path);
        println!("Processing with enrichment...\n");

        let mut enriched_count = 0;
        let mut total_improvement = 0.0;

        for record in records {
            if let Ok(enriched) = engine.enrich_url(&record.url, record.final_score).await {
                let improvement = enriched.enriched_score - record.final_score;
                if improvement > 0.0 {
                    enriched_count += 1;
                    total_improvement += improvement;
                    
                    println!("{}: {:.1} -> {:.1} ({:+.1}%)", 
                        record.url, 
                        record.final_score, 
                        enriched.enriched_score,
                        improvement
                    );
                }
            }
        }

        if enriched_count > 0 {
            println!("\n=== Summary ===");
            println!("Records enriched: {}", enriched_count);
            println!("Average improvement: {:.1}%", total_improvement / enriched_count as f64);
        }
    }

    Ok(())
}
