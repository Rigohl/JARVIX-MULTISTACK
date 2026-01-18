use anyhow::{Context, Result};
use futures::stream::{self, StreamExt};
use reqwest::Client;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Semaphore;
use tracing::{debug, info, warn};

/// Configuration for parallel downloads
#[derive(Debug, Clone)]
pub struct ParallelConfig {
    /// Maximum concurrent downloads
    pub max_concurrent: usize,
    /// Timeout per request in seconds
    pub timeout_secs: u64,
    /// Maximum retries per URL
    pub max_retries: usize,
}

impl Default for ParallelConfig {
    fn default() -> Self {
        Self {
            max_concurrent: 100,
            timeout_secs: 30,
            max_retries: 3,
        }
    }
}

/// Result of a download operation
#[derive(Debug, Clone)]
pub struct DownloadResult {
    pub url: String,
    pub success: bool,
    pub content: Option<String>,
    pub status_code: Option<u16>,
    pub error: Option<String>,
    pub duration_ms: u64,
}

/// Parallel downloader with worker pool
pub struct ParallelDownloader {
    client: Client,
    config: ParallelConfig,
    semaphore: Arc<Semaphore>,
}

impl ParallelDownloader {
    /// Create a new parallel downloader
    pub fn new(config: ParallelConfig) -> Result<Self> {
        let client = Client::builder()
            .timeout(Duration::from_secs(config.timeout_secs))
            .gzip(true)
            .user_agent("JARVIX/2.0 (Scalable OSINT Engine)")
            .build()
            .context("Failed to build HTTP client")?;

        let semaphore = Arc::new(Semaphore::new(config.max_concurrent));

        Ok(Self {
            client,
            config,
            semaphore,
        })
    }

    /// Download URLs in parallel with worker pool
    pub async fn download_all(&self, urls: Vec<String>) -> Vec<DownloadResult> {
        let total = urls.len();
        info!("Starting parallel download of {} URLs with {} workers", 
              total, self.config.max_concurrent);

        let start_time = Instant::now();

        let results: Vec<DownloadResult> = stream::iter(urls)
            .map(|url| {
                let client = self.client.clone();
                let semaphore = Arc::clone(&self.semaphore);
                let max_retries = self.config.max_retries;
                
                async move {
                    // Acquire semaphore permit to limit concurrency
                    let _permit = semaphore.acquire().await.expect("Semaphore closed");
                    
                    let result = Self::download_with_retry(&client, &url, max_retries).await;
                    debug!("Completed: {} - Success: {}", url, result.success);
                    result
                }
            })
            .buffer_unordered(self.config.max_concurrent)
            .collect()
            .await;

        let duration = start_time.elapsed();
        let success_count = results.iter().filter(|r| r.success).count();
        let avg_time_ms = duration.as_millis() as f64 / total as f64;

        info!(
            "Download completed: {}/{} successful in {:.2}s (avg {:.1}ms per URL)",
            success_count,
            total,
            duration.as_secs_f64(),
            avg_time_ms
        );

        results
    }

    /// Download a single URL with retry logic
    async fn download_with_retry(
        client: &Client,
        url: &str,
        max_retries: usize,
    ) -> DownloadResult {
        let start = Instant::now();
        
        for attempt in 0..=max_retries {
            if attempt > 0 {
                warn!("Retry {}/{} for {}", attempt, max_retries, url);
                tokio::time::sleep(Duration::from_millis(100 * attempt as u64)).await;
            }

            match Self::download_once(client, url).await {
                Ok(result) if result.success => {
                    return result;
                }
                Ok(result) if attempt == max_retries => {
                    return result; // Return failed result after max retries
                }
                Err(e) if attempt == max_retries => {
                    return DownloadResult {
                        url: url.to_string(),
                        success: false,
                        content: None,
                        status_code: None,
                        error: Some(e.to_string()),
                        duration_ms: start.elapsed().as_millis() as u64,
                    };
                }
                _ => continue, // Retry
            }
        }

        // Should not reach here
        DownloadResult {
            url: url.to_string(),
            success: false,
            content: None,
            status_code: None,
            error: Some("Max retries exceeded".to_string()),
            duration_ms: start.elapsed().as_millis() as u64,
        }
    }

    /// Download a single URL once
    async fn download_once(client: &Client, url: &str) -> Result<DownloadResult> {
        let start = Instant::now();

        let response = client
            .get(url)
            .send()
            .await
            .context("Failed to send request")?;

        let status = response.status();
        let status_code = status.as_u16();

        if status.is_success() {
            let content = response
                .text()
                .await
                .context("Failed to read response body")?;

            Ok(DownloadResult {
                url: url.to_string(),
                success: true,
                content: Some(content),
                status_code: Some(status_code),
                error: None,
                duration_ms: start.elapsed().as_millis() as u64,
            })
        } else {
            Ok(DownloadResult {
                url: url.to_string(),
                success: false,
                content: None,
                status_code: Some(status_code),
                error: Some(format!("HTTP {}", status_code)),
                duration_ms: start.elapsed().as_millis() as u64,
            })
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_parallel_download() {
        let config = ParallelConfig {
            max_concurrent: 10,
            timeout_secs: 10,
            max_retries: 1,
        };

        let downloader = ParallelDownloader::new(config).unwrap();
        
        let urls = vec![
            "https://httpbin.org/html".to_string(),
            "https://httpbin.org/json".to_string(),
        ];

        let results = downloader.download_all(urls).await;
        assert_eq!(results.len(), 2);
    }
}
