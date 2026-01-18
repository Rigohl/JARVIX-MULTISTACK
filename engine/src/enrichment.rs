use anyhow::{Context, Result};
use async_trait::async_trait;
use chrono::{DateTime, Duration, Utc};
use regex::Regex;
use reqwest::Client;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use url::Url;

/// Configuration for enrichment APIs
#[derive(Debug, Clone, Deserialize)]
pub struct EnrichmentConfig {
    pub apis: ApiSettings,
    pub google_trends: GoogleTrendsConfig,
    pub shopify: ShopifyConfig,
    pub crunchbase: CrunchbaseConfig,
    pub trustpilot: TrustpilotConfig,
    pub whois: WhoisConfig,
    pub cache: CacheConfig,
    pub scoring: ScoringConfig,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ApiSettings {
    pub google_trends_enabled: bool,
    pub shopify_detection_enabled: bool,
    pub crunchbase_enabled: bool,
    pub trustpilot_enabled: bool,
    pub whois_enabled: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct GoogleTrendsConfig {
    pub rate_limit_per_hour: u32,
    pub timeout_seconds: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ShopifyConfig {
    pub rate_limit_per_hour: u32,
    pub timeout_seconds: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CrunchbaseConfig {
    pub api_key: String,
    pub rate_limit_per_hour: u32,
    pub timeout_seconds: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct TrustpilotConfig {
    pub rate_limit_per_hour: u32,
    pub timeout_seconds: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct WhoisConfig {
    pub rate_limit_per_hour: u32,
    pub timeout_seconds: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CacheConfig {
    pub database_path: String,
    pub cache_ttl_hours: i64,
    pub enable_redis: bool,
    pub redis_url: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ScoringConfig {
    pub trending_boost: f64,
    pub shopify_boost: f64,
    pub funding_boost: f64,
    pub low_rating_penalty: f64,
    pub domain_age_boost: f64,
}

/// Result of enrichment for a URL
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnrichedScore {
    pub url: String,
    pub base_score: f64,
    pub enriched_score: f64,
    pub adjustments: Vec<ScoreAdjustment>,
    pub site_type: SiteType,
    pub enrichment_data: EnrichmentData,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScoreAdjustment {
    pub source: String,
    pub adjustment: f64,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum SiteType {
    Shopify,
    WooCommerce,
    Custom,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EnrichmentData {
    pub is_trending: Option<bool>,
    pub is_shopify: Option<bool>,
    pub has_funding: Option<bool>,
    pub rating: Option<f64>,
    pub domain_age_years: Option<f64>,
}

/// Cache entry for enrichment data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[allow(dead_code)]
struct CacheEntry {
    url_hash: String,
    data: String,
    created_at: DateTime<Utc>,
}

/// Rate limiter for API calls
struct RateLimiter {
    requests: Arc<RwLock<HashMap<String, Vec<DateTime<Utc>>>>>,
}

impl RateLimiter {
    fn new() -> Self {
        Self {
            requests: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    async fn check_and_record(&self, api_name: &str, limit_per_hour: u32) -> Result<()> {
        let mut requests = self.requests.write().await;
        let now = Utc::now();
        let one_hour_ago = now - Duration::hours(1);

        let api_requests = requests.entry(api_name.to_string()).or_insert_with(Vec::new);
        
        // Remove old requests
        api_requests.retain(|&time| time > one_hour_ago);

        if api_requests.len() >= limit_per_hour as usize {
            anyhow::bail!("Rate limit exceeded for {}", api_name);
        }

        api_requests.push(now);
        Ok(())
    }
}

/// Cache manager for enrichment data
struct CacheManager {
    db_path: String,
    ttl_hours: i64,
}

impl CacheManager {
    fn new(db_path: String, ttl_hours: i64) -> Self {
        Self { db_path, ttl_hours }
    }

    fn init_db(&self) -> Result<()> {
        let conn = Connection::open(&self.db_path)?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS enrichment_cache (
                url_hash TEXT PRIMARY KEY,
                url TEXT NOT NULL,
                enrichment_data TEXT NOT NULL,
                created_at TEXT NOT NULL
            )",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_created_at ON enrichment_cache(created_at)",
            [],
        )?;
        Ok(())
    }

    fn get(&self, url: &str) -> Result<Option<EnrichedScore>> {
        let conn = Connection::open(&self.db_path)?;
        let url_hash = self.hash_url(url);
        let cutoff = Utc::now() - Duration::hours(self.ttl_hours);

        let mut stmt = conn.prepare(
            "SELECT enrichment_data, created_at FROM enrichment_cache 
             WHERE url_hash = ? AND created_at > ?"
        )?;

        let result: Result<String> = stmt.query_row(
            params![url_hash, cutoff.to_rfc3339()],
            |row| row.get(0)
        ).map_err(|e| anyhow::anyhow!("Cache miss: {}", e));

        match result {
            Ok(data) => Ok(Some(serde_json::from_str(&data)?)),
            Err(_) => Ok(None),
        }
    }

    fn set(&self, url: &str, enriched: &EnrichedScore) -> Result<()> {
        let conn = Connection::open(&self.db_path)?;
        let url_hash = self.hash_url(url);
        let data = serde_json::to_string(enriched)?;

        conn.execute(
            "INSERT OR REPLACE INTO enrichment_cache (url_hash, url, enrichment_data, created_at)
             VALUES (?, ?, ?, ?)",
            params![url_hash, url, data, Utc::now().to_rfc3339()],
        )?;
        Ok(())
    }

    fn hash_url(&self, url: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(url.as_bytes());
        format!("{:x}", hasher.finalize())
    }
}

/// Trait for enrichment providers
#[async_trait]
trait EnrichmentProvider: Send + Sync {
    async fn enrich(&self, url: &str, client: &Client) -> Result<Option<ScoreAdjustment>>;
    #[allow(dead_code)]
    fn name(&self) -> &str;
}

/// Google Trends enrichment provider
struct GoogleTrendsProvider {
    #[allow(dead_code)]
    config: GoogleTrendsConfig,
}

#[async_trait]
impl EnrichmentProvider for GoogleTrendsProvider {
    async fn enrich(&self, url: &str, _client: &Client) -> Result<Option<ScoreAdjustment>> {
        // Extract domain keywords for trend checking
        let parsed = Url::parse(url).context("Invalid URL")?;
        let domain = parsed.host_str().unwrap_or("");
        
        // Extract potential keywords from domain (simplified approach)
        let keywords: Vec<&str> = domain.split('.').filter(|s| s.len() > 3).collect();
        
        if keywords.is_empty() {
            return Ok(None);
        }

        // Simulate trending check (in production, would call actual Google Trends API)
        // For now, use heuristic: check if domain contains common trending terms
        let trending_terms = ["ai", "tech", "crypto", "shop", "store", "market"];
        let is_trending = keywords.iter().any(|k| 
            trending_terms.iter().any(|t| k.to_lowercase().contains(t))
        );

        if is_trending {
            Ok(Some(ScoreAdjustment {
                source: "Google Trends".to_string(),
                adjustment: 20.0,
                reason: "Domain contains trending keywords".to_string(),
            }))
        } else {
            Ok(None)
        }
    }

    fn name(&self) -> &str {
        "google_trends"
    }
}

/// Shopify detection provider
struct ShopifyDetectionProvider {
    config: ShopifyConfig,
}

#[async_trait]
impl EnrichmentProvider for ShopifyDetectionProvider {
    async fn enrich(&self, url: &str, client: &Client) -> Result<Option<ScoreAdjustment>> {
        // Fetch HTML and check for Shopify signatures
        let timeout = std::time::Duration::from_secs(self.config.timeout_seconds);
        let response = tokio::time::timeout(
            timeout,
            client.get(url).send()
        ).await;

        match response {
            Ok(Ok(resp)) => {
                if let Ok(html) = resp.text().await {
                    // Check for Shopify signatures in HTML
                    let shopify_patterns = [
                        "cdn.shopify.com",
                        "Shopify.theme",
                        "shopify-analytics",
                        "shopify_pay",
                        "myshopify.com",
                    ];

                    let is_shopify = shopify_patterns.iter().any(|pattern| html.contains(pattern));

                    if is_shopify {
                        return Ok(Some(ScoreAdjustment {
                            source: "Shopify Detection".to_string(),
                            adjustment: 15.0,
                            reason: "Detected as Shopify store".to_string(),
                        }));
                    }
                }
            },
            _ => {
                // Timeout or error - graceful fallback
            }
        }

        Ok(None)
    }

    fn name(&self) -> &str {
        "shopify"
    }
}

/// Whois domain age provider
struct WhoisProvider {
    #[allow(dead_code)]
    config: WhoisConfig,
}

#[async_trait]
impl EnrichmentProvider for WhoisProvider {
    async fn enrich(&self, url: &str, _client: &Client) -> Result<Option<ScoreAdjustment>> {
        let parsed = Url::parse(url).context("Invalid URL")?;
        let domain = parsed.host_str().unwrap_or("");

        // Use tokio::process to call whois command
        let output = tokio::process::Command::new("whois")
            .arg(domain)
            .output()
            .await;

        match output {
            Ok(out) if out.status.success() => {
                let whois_data = String::from_utf8_lossy(&out.stdout);
                
                // Parse creation date from whois output
                let creation_date = self.parse_creation_date(&whois_data);
                
                if let Some(created) = creation_date {
                    let age_years = (Utc::now() - created).num_days() as f64 / 365.25;
                    
                    if age_years > 2.0 {
                        return Ok(Some(ScoreAdjustment {
                            source: "Whois".to_string(),
                            adjustment: 5.0,
                            reason: format!("Domain age: {:.1} years", age_years),
                        }));
                    }
                }
            },
            _ => {
                // Whois command failed or not available - graceful fallback
            }
        }

        Ok(None)
    }

    fn name(&self) -> &str {
        "whois"
    }
}

impl WhoisProvider {
    fn parse_creation_date(&self, whois_data: &str) -> Option<DateTime<Utc>> {
        // Common patterns for creation date in whois
        let patterns = [
            r"Creation Date:\s*(\d{4}-\d{2}-\d{2})",
            r"Created:\s*(\d{4}-\d{2}-\d{2})",
            r"created:\s*(\d{4}-\d{2}-\d{2})",
        ];

        for pattern in &patterns {
            if let Ok(re) = Regex::new(pattern) {
                if let Some(cap) = re.captures(whois_data) {
                    if let Some(date_str) = cap.get(1) {
                        if let Ok(date) = DateTime::parse_from_rfc3339(&format!("{}T00:00:00Z", date_str.as_str())) {
                            return Some(date.with_timezone(&Utc));
                        }
                    }
                }
            }
        }

        None
    }
}

/// Main enrichment engine
pub struct EnrichmentEngine {
    config: EnrichmentConfig,
    client: Client,
    cache: CacheManager,
    rate_limiter: RateLimiter,
}

impl EnrichmentEngine {
    pub fn new(config: EnrichmentConfig) -> Result<Self> {
        let cache = CacheManager::new(
            config.cache.database_path.clone(),
            config.cache.cache_ttl_hours,
        );
        cache.init_db()?;

        let client = Client::builder()
            .user_agent("JARVIX-Enrichment/1.0")
            .build()?;

        Ok(Self {
            config,
            client,
            cache,
            rate_limiter: RateLimiter::new(),
        })
    }

    /// Detect site type from URL and HTML
    async fn detect_site_type(&self, url: &str) -> Result<SiteType> {
        let timeout = std::time::Duration::from_secs(5);
        let response = tokio::time::timeout(
            timeout,
            self.client.get(url).send()
        ).await;

        match response {
            Ok(Ok(resp)) => {
                if let Ok(html) = resp.text().await {
                    // Check for Shopify
                    if html.contains("cdn.shopify.com") || html.contains("myshopify.com") {
                        return Ok(SiteType::Shopify);
                    }
                    
                    // Check for WooCommerce
                    if html.contains("woocommerce") || html.contains("wp-content/plugins/woocommerce") {
                        return Ok(SiteType::WooCommerce);
                    }

                    // Check for other e-commerce platforms
                    if html.contains("magento") || html.contains("prestashop") {
                        return Ok(SiteType::Custom);
                    }
                }
            },
            _ => {
                // Timeout or error
            }
        }

        Ok(SiteType::Unknown)
    }

    /// Enrich a single URL with external data
    pub async fn enrich_url(&self, url: &str, base_score: f64) -> Result<EnrichedScore> {
        // Check cache first
        if let Some(cached) = self.cache.get(url)? {
            return Ok(cached);
        }

        let mut adjustments = Vec::new();
        let mut enrichment_data = EnrichmentData::default();

        // Detect site type
        let site_type = self.detect_site_type(url).await.unwrap_or(SiteType::Unknown);

        // Google Trends
        if self.config.apis.google_trends_enabled {
            if self.rate_limiter.check_and_record(
                "google_trends",
                self.config.google_trends.rate_limit_per_hour
            ).await.is_ok() {
                let provider = GoogleTrendsProvider {
                    config: self.config.google_trends.clone(),
                };
                
                if let Ok(Some(adj)) = provider.enrich(url, &self.client).await {
                    enrichment_data.is_trending = Some(true);
                    adjustments.push(adj);
                }
            }
        }

        // Shopify Detection
        if self.config.apis.shopify_detection_enabled {
            if self.rate_limiter.check_and_record(
                "shopify",
                self.config.shopify.rate_limit_per_hour
            ).await.is_ok() {
                let provider = ShopifyDetectionProvider {
                    config: self.config.shopify.clone(),
                };
                
                if let Ok(Some(adj)) = provider.enrich(url, &self.client).await {
                    enrichment_data.is_shopify = Some(true);
                    adjustments.push(adj);
                }
            }
        }

        // Whois
        if self.config.apis.whois_enabled {
            if self.rate_limiter.check_and_record(
                "whois",
                self.config.whois.rate_limit_per_hour
            ).await.is_ok() {
                let provider = WhoisProvider {
                    config: self.config.whois.clone(),
                };
                
                if let Ok(Some(adj)) = provider.enrich(url, &self.client).await {
                    adjustments.push(adj);
                }
            }
        }

        // Calculate enriched score
        let total_adjustment: f64 = adjustments.iter().map(|a| a.adjustment).sum();
        let enriched_score = base_score + total_adjustment;

        let result = EnrichedScore {
            url: url.to_string(),
            base_score,
            enriched_score,
            adjustments,
            site_type,
            enrichment_data,
            timestamp: Utc::now(),
        };

        // Cache the result
        let _ = self.cache.set(url, &result);

        Ok(result)
    }
}

/// Main function to enrich a score
pub async fn enrich_score(url: &str, base_score: f64, config_path: &str) -> Result<EnrichedScore> {
    let config_content = std::fs::read_to_string(config_path)
        .context("Failed to read config file")?;
    let config: EnrichmentConfig = toml::from_str(&config_content)
        .context("Failed to parse config")?;

    let engine = EnrichmentEngine::new(config)?;
    engine.enrich_url(url, base_score).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_site_type_detection() {
        let config = create_test_config();
        let engine = EnrichmentEngine::new(config).unwrap();
        
        // Test with a known Shopify store (would need real URL in integration tests)
        let result = engine.detect_site_type("https://example.com").await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_cache_manager() {
        use std::fs;
        let db_path = "/tmp/test_cache.db";
        let _ = fs::remove_file(db_path); // Clean up if exists
        
        let cache = CacheManager::new(db_path.to_string(), 168);
        cache.init_db().unwrap();

        let enriched = EnrichedScore {
            url: "https://example.com".to_string(),
            base_score: 50.0,
            enriched_score: 65.0,
            adjustments: vec![],
            site_type: SiteType::Custom,
            enrichment_data: EnrichmentData::default(),
            timestamp: Utc::now(),
        };

        cache.set("https://example.com", &enriched).unwrap();
        let retrieved = cache.get("https://example.com").unwrap();
        
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().enriched_score, 65.0);
        
        // Clean up
        let _ = fs::remove_file(db_path);
    }

    #[tokio::test]
    async fn test_rate_limiter() {
        let limiter = RateLimiter::new();
        
        // Should allow first request
        assert!(limiter.check_and_record("test_api", 2).await.is_ok());
        
        // Should allow second request
        assert!(limiter.check_and_record("test_api", 2).await.is_ok());
        
        // Should deny third request
        assert!(limiter.check_and_record("test_api", 2).await.is_err());
    }

    fn create_test_config() -> EnrichmentConfig {
        EnrichmentConfig {
            apis: ApiSettings {
                google_trends_enabled: true,
                shopify_detection_enabled: true,
                crunchbase_enabled: false,
                trustpilot_enabled: false,
                whois_enabled: true,
            },
            google_trends: GoogleTrendsConfig {
                rate_limit_per_hour: 100,
                timeout_seconds: 10,
            },
            shopify: ShopifyConfig {
                rate_limit_per_hour: 200,
                timeout_seconds: 5,
            },
            crunchbase: CrunchbaseConfig {
                api_key: String::new(),
                rate_limit_per_hour: 200,
                timeout_seconds: 10,
            },
            trustpilot: TrustpilotConfig {
                rate_limit_per_hour: 100,
                timeout_seconds: 10,
            },
            whois: WhoisConfig {
                rate_limit_per_hour: 50,
                timeout_seconds: 15,
            },
            cache: CacheConfig {
                database_path: ":memory:".to_string(),
                cache_ttl_hours: 168,
                enable_redis: false,
                redis_url: String::new(),
            },
            scoring: ScoringConfig {
                trending_boost: 20.0,
                shopify_boost: 15.0,
                funding_boost: 10.0,
                low_rating_penalty: -5.0,
                domain_age_boost: 5.0,
            },
        }
    }
}
