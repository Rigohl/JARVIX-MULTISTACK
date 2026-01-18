use jarvix::enrich_score;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("JARVIX External Data Enrichment Demo");
    println!("=====================================\n");

    let config_path = "data/api_config.toml";
    
    // Test URLs
    let test_urls = vec![
        ("https://www.shopify.com", 50.0),
        ("https://techcrunch.com", 45.0),
        ("https://example.com", 40.0),
    ];

    for (url, base_score) in test_urls {
        println!("Processing: {}", url);
        println!("Base score: {:.1}", base_score);
        
        match enrich_score(url, base_score, config_path).await {
            Ok(enriched) => {
                println!("✓ Enriched score: {:.1}", enriched.enriched_score);
                println!("  Site type: {:?}", enriched.site_type);
                
                if !enriched.adjustments.is_empty() {
                    println!("  Adjustments:");
                    for adj in &enriched.adjustments {
                        println!("    - {}: {:+.1}% ({})", adj.source, adj.adjustment, adj.reason);
                    }
                }
                
                if let Some(trending) = enriched.enrichment_data.is_trending {
                    println!("  Trending: {}", trending);
                }
                if let Some(shopify) = enriched.enrichment_data.is_shopify {
                    println!("  Shopify store: {}", shopify);
                }
            }
            Err(e) => {
                println!("✗ Error: {}", e);
            }
        }
        
        println!();
    }

    Ok(())
}
