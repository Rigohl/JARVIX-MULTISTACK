use anyhow::{Result, anyhow};
use reqwest::Client;
use std::time::Duration;
use url::Url;

const USER_AGENT: &str = "JARVIX-Bot/1.0 (Intelligence Discovery; +https://github.com/Rigohl/JARVIX-MULTISTACK)";

/// Check if a domain respects robots.txt for our user agent
pub async fn check_robots_txt(domain: &str) -> Result<bool> {
    let client = Client::builder()
        .timeout(Duration::from_secs(10))
        .user_agent(USER_AGENT)
        .build()?;
    
    // Ensure domain has a scheme
    let url = if domain.starts_with("http://") || domain.starts_with("https://") {
        domain.to_string()
    } else {
        format!("https://{}", domain)
    };
    
    let parsed = Url::parse(&url)?;
    let robots_url = format!("{}://{}/robots.txt", 
        parsed.scheme(), 
        parsed.host_str().ok_or_else(|| anyhow!("Invalid host"))?
    );
    
    // Try to fetch robots.txt
    match client.get(&robots_url).send().await {
        Ok(response) => {
            if response.status().is_success() {
                let text = response.text().await?;
                // Parse robots.txt and check if our user agent is allowed
                Ok(is_allowed_by_robots(&text, USER_AGENT))
            } else {
                // If no robots.txt, assume allowed
                Ok(true)
            }
        }
        Err(_) => {
            // If can't fetch robots.txt (timeout, connection error), assume allowed
            Ok(true)
        }
    }
}

/// Parse robots.txt content and check if user agent is allowed
fn is_allowed_by_robots(robots_txt: &str, user_agent: &str) -> bool {
    let mut current_agents: Vec<String> = Vec::new();
    let mut is_relevant_section = false;
    let mut disallowed_paths: Vec<String> = Vec::new();
    
    for line in robots_txt.lines() {
        let line = line.trim();
        
        // Skip comments and empty lines
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        
        if line.to_lowercase().starts_with("user-agent:") {
            let agent = line.split(':').nth(1).unwrap_or("").trim().to_lowercase();
            current_agents.push(agent.clone());
            
            // Check if this section applies to us
            is_relevant_section = agent == "*" || 
                agent.contains("jarvix") || 
                user_agent.to_lowercase().contains(&agent);
        } else if line.to_lowercase().starts_with("disallow:") && is_relevant_section {
            let path = line.split(':').nth(1).unwrap_or("").trim();
            if path == "/" {
                // Disallow all - we should not crawl this site
                return false;
            }
            disallowed_paths.push(path.to_string());
        }
    }
    
    // For discovery purposes, we only check if the root is allowed
    // If there are disallowed paths but root is not explicitly disallowed, we consider it allowed
    true
}

/// Validate that a domain is properly formatted
pub fn validate_domain(domain: &str) -> Result<String> {
    let domain = domain.trim();
    
    // Remove protocol if present
    let domain = domain
        .strip_prefix("http://")
        .or_else(|| domain.strip_prefix("https://"))
        .unwrap_or(domain);
    
    // Remove trailing slash and path
    let domain = domain.split('/').next().unwrap_or(domain);
    
    // Basic validation
    if domain.is_empty() {
        return Err(anyhow!("Empty domain"));
    }
    
    if !domain.contains('.') {
        return Err(anyhow!("Invalid domain format"));
    }
    
    // Check for valid characters
    if !domain.chars().all(|c| c.is_alphanumeric() || c == '.' || c == '-') {
        return Err(anyhow!("Invalid characters in domain"));
    }
    
    Ok(domain.to_string())
}

/// Generate TLD variations for a domain
pub fn generate_tld_variations(base_domain: &str, region: &str) -> Vec<String> {
    let mut variations = Vec::new();
    
    // Extract domain name without TLD
    let parts: Vec<&str> = base_domain.rsplitn(2, '.').collect();
    let domain_name = if parts.len() == 2 {
        parts[1]
    } else {
        base_domain
    };
    
    // Common TLDs
    let common_tlds = vec!["com", "net", "org", "io"];
    
    // Region-specific TLDs
    let region_lower = region.to_lowercase();
    let region_tld = match region.to_uppercase().as_str() {
        "ES" => "es",
        "US" => "us",
        "UK" => "uk",
        "FR" => "fr",
        "DE" => "de",
        "IT" => "it",
        _ => region_lower.as_str(),
    };
    
    // Add common TLD variations
    for tld in common_tlds {
        variations.push(format!("{}.{}", domain_name, tld));
    }
    
    // Add region-specific TLD
    if !variations.contains(&format!("{}.{}", domain_name, region_tld)) {
        variations.push(format!("{}.{}", domain_name, region_tld));
    }
    
    // Add some common ccTLDs
    variations.push(format!("{}.co", domain_name));
    variations.push(format!("{}.co.{}", domain_name, region_tld));
    
    variations
}

/// Check if a domain is reachable
pub async fn is_domain_reachable(domain: &str) -> bool {
    let client = Client::builder()
        .timeout(Duration::from_secs(5))
        .user_agent(USER_AGENT)
        .build();
    
    if let Ok(client) = client {
        let url = if domain.starts_with("http") {
            domain.to_string()
        } else {
            format!("https://{}", domain)
        };
        
        match client.head(&url).send().await {
            Ok(response) => response.status().is_success() || response.status().is_redirection(),
            Err(_) => false,
        }
    } else {
        false
    }
}
