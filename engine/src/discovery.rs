use anyhow::Result;
use std::collections::{HashSet, HashMap};
use std::fs::File;
use std::io::Write;

use crate::db;
use crate::policy;

/// Niche-specific seed domains and keywords for discovery
fn get_niche_seeds(niche: &str) -> Vec<String> {
    let niche_lower = niche.to_lowercase();
    
    match niche_lower.as_str() {
        "ecommerce" => vec![
            "shopify".to_string(),
            "woocommerce".to_string(),
            "bigcommerce".to_string(),
            "magento".to_string(),
            "prestashop".to_string(),
            "opencart".to_string(),
            "amazon".to_string(),
            "ebay".to_string(),
            "etsy".to_string(),
            "walmart".to_string(),
        ],
        "saas" => vec![
            "salesforce".to_string(),
            "hubspot".to_string(),
            "zendesk".to_string(),
            "atlassian".to_string(),
            "slack".to_string(),
            "notion".to_string(),
            "asana".to_string(),
            "monday".to_string(),
        ],
        "fitness" => vec![
            "peloton".to_string(),
            "fitbit".to_string(),
            "myfitnesspal".to_string(),
            "strava".to_string(),
            "gymshark".to_string(),
            "nike".to_string(),
            "underarmour".to_string(),
            "lululemon".to_string(),
        ],
        "fintech" => vec![
            "stripe".to_string(),
            "paypal".to_string(),
            "square".to_string(),
            "revolut".to_string(),
            "wise".to_string(),
            "klarna".to_string(),
            "adyen".to_string(),
        ],
        "edtech" => vec![
            "coursera".to_string(),
            "udemy".to_string(),
            "skillshare".to_string(),
            "duolingo".to_string(),
            "khan".to_string(),
            "codecademy".to_string(),
        ],
        _ => vec![
            "example".to_string(),
            "demo".to_string(),
            "test".to_string(),
        ],
    }
}

/// Get region-specific domain patterns
fn get_region_patterns(region: &str) -> Vec<String> {
    let region_upper = region.to_uppercase();
    
    match region_upper.as_str() {
        "ES" => vec!["es".to_string(), "cat".to_string()],
        "US" => vec!["com".to_string(), "us".to_string()],
        "UK" => vec!["uk".to_string(), "co.uk".to_string()],
        "FR" => vec!["fr".to_string()],
        "DE" => vec!["de".to_string()],
        "IT" => vec!["it".to_string()],
        "BR" => vec!["br".to_string(), "com.br".to_string()],
        "JP" => vec!["jp".to_string(), "co.jp".to_string()],
        _ => vec!["com".to_string()],
    }
}

/// Discover domains based on niche and region
pub async fn discover_domains(
    niche: &str,
    region: &str,
    max_domains: usize,
    db_path: &str,
) -> Result<Vec<String>> {
    println!("📊 Starting domain discovery...");
    
    // Check cache first
    let cached = db::get_cached_domains(db_path, niche, region)?;
    if !cached.is_empty() {
        println!("💾 Found {} cached domains", cached.len());
        let limited = cached.into_iter().take(max_domains).collect();
        return Ok(limited);
    }
    
    println!("🔍 No cache found, discovering new domains...");
    
    let mut discovered: HashSet<String> = HashSet::new();
    let mut scores: HashMap<String, f64> = HashMap::new();
    
    // Get seed domains for the niche
    let seeds = get_niche_seeds(niche);
    let region_tlds = get_region_patterns(region);
    
    println!("🌱 Using {} seed domains for niche '{}'", seeds.len(), niche);
    
    // Generate domain variations
    for seed in seeds.iter() {
        // Add base seed
        let base_domain = format!("{}.com", seed);
        discovered.insert(base_domain.clone());
        scores.insert(base_domain, 1.0);
        
        // Add region-specific TLD variations
        for tld in region_tlds.iter() {
            let domain = format!("{}.{}", seed, tld);
            discovered.insert(domain.clone());
            scores.insert(domain, 0.9); // Slightly lower score for variations
        }
        
        // Add common variations
        let variations = vec![
            format!("{}-{}.com", seed, region.to_lowercase()),
            format!("{}{}.com", seed, region.to_lowercase()),
            format!("shop{}.com", seed),
            format!("{}shop.com", seed),
            format!("get{}.com", seed),
            format!("my{}.com", seed),
        ];
        
        for var in variations {
            discovered.insert(var.clone());
            scores.insert(var, 0.7);
        }
    }
    
    println!("🔎 Generated {} candidate domains", discovered.len());
    
    // Filter and validate domains
    let mut validated_domains: Vec<(String, f64)> = Vec::new();
    
    for domain in discovered.iter() {
        // Validate domain format
        if let Ok(clean_domain) = policy::validate_domain(domain) {
            // Check robots.txt compliance
            println!("🤖 Checking robots.txt for {}", clean_domain);
            
            let robots_ok = match policy::check_robots_txt(&clean_domain).await {
                Ok(allowed) => allowed,
                Err(_) => {
                    // If we can't check, assume it's okay but lower the score
                    true
                }
            };
            
            if robots_ok {
                // Check if domain is reachable
                let reachable = policy::is_domain_reachable(&clean_domain).await;
                
                let score = scores.get(domain).copied().unwrap_or(0.5);
                let final_score = if reachable { score } else { score * 0.5 };
                
                if reachable {
                    println!("✅ {}: reachable (score: {:.2})", clean_domain, final_score);
                } else {
                    println!("⚠️  {}: not reachable (score: {:.2})", clean_domain, final_score);
                }
                
                validated_domains.push((clean_domain.clone(), final_score));
                
                // Cache the domain
                db::cache_domain(
                    db_path,
                    niche,
                    region,
                    &clean_domain,
                    final_score,
                    robots_ok,
                )?;
            } else {
                println!("❌ {}: blocked by robots.txt", clean_domain);
            }
        }
    }
    
    // Sort by score (highest first)
    validated_domains.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    
    // Take top N domains
    let result: Vec<String> = validated_domains
        .into_iter()
        .take(max_domains)
        .map(|(domain, _)| domain)
        .collect();
    
    // Log the discovery
    db::log_event(
        db_path,
        &format!("discovery_{}_{}", niche, region),
        "discovery.completed",
        None,
        "success",
        &format!("Discovered {} domains", result.len()),
        Some(&format!(r#"{{"niche": "{}", "region": "{}", "count": {}}}"#, niche, region, result.len())),
    )?;
    
    Ok(result)
}

/// Write discovered domains to a seeds file
pub fn write_seeds_file(domains: &[String], output_path: &str) -> Result<()> {
    // Ensure parent directory exists
    if let Some(parent) = std::path::Path::new(output_path).parent() {
        std::fs::create_dir_all(parent)?;
    }
    
    let mut file = File::create(output_path)?;
    
    for domain in domains {
        // Write full URL format for compatibility with collect command
        let url = if domain.starts_with("http") {
            domain.clone()
        } else {
            format!("https://{}", domain)
        };
        writeln!(file, "{}", url)?;
    }
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_niche_seeds() {
        let seeds = get_niche_seeds("ecommerce");
        assert!(!seeds.is_empty());
        assert!(seeds.contains(&"shopify".to_string()));
        
        let saas_seeds = get_niche_seeds("saas");
        assert!(!saas_seeds.is_empty());
    }

    #[test]
    fn test_get_region_patterns() {
        let patterns = get_region_patterns("ES");
        assert!(patterns.contains(&"es".to_string()));
        
        let uk_patterns = get_region_patterns("UK");
        assert!(uk_patterns.contains(&"uk".to_string()));
    }
    
    #[test]
    fn test_write_seeds_file() {
        let domains = vec![
            "example.com".to_string(),
            "test.com".to_string(),
        ];
        
        let temp_dir = tempfile::tempdir().unwrap();
        let output_path = temp_dir.path().join("seeds.txt");
        
        write_seeds_file(&domains, output_path.to_str().unwrap()).unwrap();
        
        let content = std::fs::read_to_string(&output_path).unwrap();
        assert!(content.contains("https://example.com"));
        assert!(content.contains("https://test.com"));
    }
}
