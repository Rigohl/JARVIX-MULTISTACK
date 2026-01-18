use anyhow::Result;
use rusqlite::{Connection, params};
use chrono::Utc;

/// Initialize the SQLite database with required tables
pub fn migrate(db_path: &str) -> Result<()> {
    let conn = Connection::open(db_path)?;
    
    // Events table for logging
    conn.execute(
        "CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            run_id TEXT NOT NULL,
            event_type TEXT NOT NULL,
            url TEXT,
            status TEXT,
            message TEXT,
            metadata TEXT
        )",
        [],
    )?;
    
    // Create indices for events
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_events_run_id ON events(run_id)",
        [],
    )?;
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type)",
        [],
    )?;
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp)",
        [],
    )?;
    
    // Discovery cache table
    conn.execute(
        "CREATE TABLE IF NOT EXISTS discovery_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            niche TEXT NOT NULL,
            region TEXT NOT NULL,
            domain TEXT NOT NULL,
            discovered_at TEXT NOT NULL,
            relevance_score REAL DEFAULT 0.0,
            robots_allowed INTEGER DEFAULT 1,
            UNIQUE(niche, region, domain)
        )",
        [],
    )?;
    
    // Create indices for discovery cache
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_discovery_niche_region ON discovery_cache(niche, region)",
        [],
    )?;
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_discovery_domain ON discovery_cache(domain)",
        [],
    )?;
    
    Ok(())
}

/// Log an event to the database
pub fn log_event(
    db_path: &str,
    run_id: &str,
    event_type: &str,
    url: Option<&str>,
    status: &str,
    message: &str,
    metadata: Option<&str>,
) -> Result<()> {
    let conn = Connection::open(db_path)?;
    let timestamp = Utc::now().to_rfc3339();
    
    conn.execute(
        "INSERT INTO events (timestamp, run_id, event_type, url, status, message, metadata)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        params![timestamp, run_id, event_type, url, status, message, metadata],
    )?;
    
    Ok(())
}

/// Check if a domain is already cached for a given niche and region
pub fn check_cache(
    db_path: &str,
    niche: &str,
    region: &str,
    domain: &str,
) -> Result<bool> {
    let conn = Connection::open(db_path)?;
    let mut stmt = conn.prepare(
        "SELECT COUNT(*) FROM discovery_cache WHERE niche = ?1 AND region = ?2 AND domain = ?3"
    )?;
    
    let count: i64 = stmt.query_row(params![niche, region, domain], |row| row.get(0))?;
    Ok(count > 0)
}

/// Cache a discovered domain
pub fn cache_domain(
    db_path: &str,
    niche: &str,
    region: &str,
    domain: &str,
    relevance_score: f64,
    robots_allowed: bool,
) -> Result<()> {
    let conn = Connection::open(db_path)?;
    let timestamp = Utc::now().to_rfc3339();
    
    conn.execute(
        "INSERT OR REPLACE INTO discovery_cache 
         (niche, region, domain, discovered_at, relevance_score, robots_allowed)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![niche, region, domain, timestamp, relevance_score, robots_allowed as i32],
    )?;
    
    Ok(())
}

/// Get cached domains for a niche and region
pub fn get_cached_domains(
    db_path: &str,
    niche: &str,
    region: &str,
) -> Result<Vec<String>> {
    let conn = Connection::open(db_path)?;
    let mut stmt = conn.prepare(
        "SELECT domain FROM discovery_cache 
         WHERE niche = ?1 AND region = ?2 AND robots_allowed = 1
         ORDER BY relevance_score DESC"
    )?;
    
    let domains = stmt.query_map(params![niche, region], |row| {
        row.get::<_, String>(0)
    })?
    .filter_map(|r| r.ok())
    .collect();
    
    Ok(domains)
}
