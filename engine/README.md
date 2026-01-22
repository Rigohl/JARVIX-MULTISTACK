# JARVIX Engine - External Data Enrichment

**For complete agent architecture, see [../AGENTS.md](../AGENTS.md) - Enrichment Agent section**

---

This module provides external data enrichment capabilities for the JARVIX scoring system.

## Features

- **Multi-Source Enrichment**: Integrate data from multiple external APIs
  - Google Trends (trending keyword detection)
  - Shopify store detection (HTML signature analysis)
  - Crunchbase (startup funding information)
  - Trustpilot (review ratings)
  - Whois (domain age verification)

- **Intelligent Caching**: SQLite-based caching system with configurable TTL
  - 7-day default cache lifetime
  - SHA-256 URL hashing for efficient lookups
  - Optional Redis support for distributed caching

- **Rate Limiting**: Per-API rate limiting to respect service limits
  - Configurable limits per hour for each API
  - Automatic request tracking and enforcement

- **Graceful Fallbacks**: Continue processing even if APIs fail
  - Individual API failures don't break the pipeline
  - Partial enrichment is better than no enrichment

- **Site Type Detection**: Automatic detection of e-commerce platforms
  - Shopify
  - WooCommerce
  - Custom platforms

## Configuration

Edit `data/api_config.toml` to configure:

```toml
[apis]
google_trends_enabled = true
shopify_detection_enabled = true
crunchbase_enabled = false
trustpilot_enabled = true
whois_enabled = true

[scoring]
trending_boost = 20.0      # +20% if trending
shopify_boost = 15.0       # +15% if Shopify store
funding_boost = 10.0       # +10% if funded startup
low_rating_penalty = -5.0  # -5% if rating < 3 stars
domain_age_boost = 5.0     # +5% if domain > 2 years
```

## Usage

### Basic Example

```rust
use jarvix::enrich_score;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let url = "https://example.com";
    let base_score = 50.0;
    let config_path = "data/api_config.toml";
    
    let enriched = enrich_score(url, base_score, config_path).await?;
    
    println!("Base score: {}", enriched.base_score);
    println!("Enriched score: {}", enriched.enriched_score);
    println!("Site type: {:?}", enriched.site_type);
    
    for adjustment in enriched.adjustments {
        println!("  {} adjusted by {:+.1}%: {}", 
            adjustment.source, 
            adjustment.adjustment, 
            adjustment.reason
        );
    }
    
    Ok(())
}
```

### Advanced Usage

```rust
use jarvix::{EnrichmentEngine, EnrichmentConfig};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load configuration
    let config: EnrichmentConfig = toml::from_str(&std::fs::read_to_string("data/api_config.toml")?)?;
    
    // Create engine
    let engine = EnrichmentEngine::new(config)?;
    
    // Enrich multiple URLs
    let urls = vec![
        "https://example1.com",
        "https://example2.com",
        "https://example3.com",
    ];
    
    for url in urls {
        let enriched = engine.enrich_url(url, 50.0).await?;
        println!("{}: {:.1}", url, enriched.enriched_score);
    }
    
    Ok(())
}
```

## Running Examples

```bash
# Run the basic enrichment example
cargo run --example basic_enrichment

# Run with custom config
CONFIG_PATH=data/api_config.toml cargo run --example basic_enrichment
```

## Testing

```bash
# Run all tests
cargo test

# Run tests with output
cargo test -- --nocapture

# Run specific test
cargo test test_cache_manager
```

## Performance

The enrichment engine is designed to handle:

- **100 URLs in < 30 seconds** (with caching)
- Concurrent API requests using tokio
- Automatic rate limiting to prevent API abuse
- Efficient caching to minimize redundant requests

## Database Schema

The enrichment cache uses the following SQLite schema:

```sql
CREATE TABLE enrichment_cache (
    url_hash TEXT PRIMARY KEY,
    url TEXT NOT NULL,
    enrichment_data TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX idx_created_at ON enrichment_cache(created_at);
```

## Dependencies

- `tokio` - Async runtime
- `reqwest` - HTTP client
- `rusqlite` - SQLite database
- `serde` - Serialization
- `redis` - Optional Redis caching
- `anyhow` - Error handling
- `chrono` - Date/time handling

## Architecture

```
EnrichmentEngine
├── CacheManager (SQLite)
├── RateLimiter (in-memory)
└── Providers
    ├── GoogleTrendsProvider
    ├── ShopifyDetectionProvider
    ├── CrunchbaseProvider (optional)
    ├── TrustpilotProvider (optional)
    └── WhoisProvider
```

## License

Part of the JARVIX-MULTISTACK project.
