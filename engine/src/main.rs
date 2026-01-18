use clap::{Parser, Subcommand};
use anyhow::Result;

mod db;
mod discovery;
mod policy;

#[derive(Parser)]
#[command(name = "jarvix")]
#[command(about = "JARVIX - Intelligence Factory for Competitor Discovery and Analysis", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize the SQLite database
    Migrate {
        /// Path to the SQLite database file
        #[arg(value_name = "DB_PATH")]
        db_path: String,
    },
    /// Discover competitors automatically based on niche and region
    Discover {
        /// Niche/market segment (e.g., "ecommerce", "saas", "fitness")
        #[arg(long)]
        niche: String,
        
        /// Region code (e.g., "ES", "US", "UK")
        #[arg(long)]
        region: String,
        
        /// Maximum number of domains to discover (default: 100)
        #[arg(long, default_value = "100")]
        max_domains: usize,
        
        /// Database path for caching discovered domains
        #[arg(long, default_value = "data/jarvix.db")]
        db_path: String,
        
        /// Output file path for discovered seeds
        #[arg(long)]
        output: Option<String>,
    },
    /// Collect data from seed URLs (placeholder for future implementation)
    Collect {
        /// Run ID for this collection
        #[arg(long)]
        run: String,
        
        /// Input file with seed URLs
        #[arg(long)]
        input: String,
    },
    /// Curate collected data (placeholder for future implementation)
    Curate {
        /// Run ID to curate
        #[arg(long)]
        run: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Migrate { db_path } => {
            println!("🔧 Initializing database at: {}", db_path);
            db::migrate(&db_path)?;
            println!("✅ Database initialized successfully");
            Ok(())
        }
        Commands::Discover {
            niche,
            region,
            max_domains,
            db_path,
            output,
        } => {
            println!("🔍 Discovering competitors for niche: {}, region: {}", niche, region);
            
            // Initialize database if it doesn't exist
            if !std::path::Path::new(&db_path).exists() {
                db::migrate(&db_path)?;
            }
            
            // Run discovery
            let domains = discovery::discover_domains(
                &niche,
                &region,
                max_domains,
                &db_path,
            ).await?;
            
            // Generate output filename if not provided
            let output_path = output.unwrap_or_else(|| {
                format!("data/discovered_seeds_{}_{}.txt", niche, region)
            });
            
            // Write domains to output file
            discovery::write_seeds_file(&domains, &output_path)?;
            
            println!("✅ Discovered {} domains", domains.len());
            println!("📝 Seeds written to: {}", output_path);
            
            Ok(())
        }
        Commands::Collect { run, input } => {
            println!("📥 Collect command not yet implemented");
            println!("Run ID: {}, Input: {}", run, input);
            Ok(())
        }
        Commands::Curate { run } => {
            println!("🧹 Curate command not yet implemented");
            println!("Run ID: {}", run);
            Ok(())
        }
    }
}
