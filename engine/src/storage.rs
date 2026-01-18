use anyhow::{Context, Result};
use arrow::array::{ArrayRef, StringArray, UInt64Array, BooleanArray};
use arrow::datatypes::{DataType, Field, Schema};
use arrow::record_batch::RecordBatch;
use parquet::arrow::ArrowWriter;
use parquet::file::properties::WriterProperties;
use parquet::basic::{Compression, GzipLevel};
use std::fs::File;
use std::path::Path;
use std::sync::Arc;
use tracing::{info, debug};

use crate::parallel::DownloadResult;

/// Storage manager for Parquet columnar format
pub struct ParquetStorage {
    compression: Compression,
}

impl ParquetStorage {
    /// Create a new Parquet storage manager
    pub fn new() -> Self {
        Self {
            compression: Compression::GZIP(GzipLevel::default()),
        }
    }

    /// Save download results to Parquet file
    pub fn save_results<P: AsRef<Path>>(
        &self,
        results: &[DownloadResult],
        output_path: P,
    ) -> Result<()> {
        let path = output_path.as_ref();
        info!("Saving {} results to Parquet: {:?}", results.len(), path);

        // Ensure parent directory exists
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .context("Failed to create parent directory")?;
        }

        // Define schema
        let schema = Arc::new(Schema::new(vec![
            Field::new("url", DataType::Utf8, false),
            Field::new("success", DataType::Boolean, false),
            Field::new("content", DataType::Utf8, true),
            Field::new("status_code", DataType::UInt64, true),
            Field::new("error", DataType::Utf8, true),
            Field::new("duration_ms", DataType::UInt64, false),
        ]));

        // Prepare data arrays
        let urls: Vec<&str> = results.iter().map(|r| r.url.as_str()).collect();
        let success: Vec<bool> = results.iter().map(|r| r.success).collect();
        let contents: Vec<Option<&str>> = results
            .iter()
            .map(|r| r.content.as_deref())
            .collect();
        let status_codes: Vec<Option<u64>> = results
            .iter()
            .map(|r| r.status_code.map(|c| c as u64))
            .collect();
        let errors: Vec<Option<&str>> = results
            .iter()
            .map(|r| r.error.as_deref())
            .collect();
        let durations: Vec<u64> = results.iter().map(|r| r.duration_ms).collect();

        // Create arrays
        let url_array = Arc::new(StringArray::from(urls)) as ArrayRef;
        let success_array = Arc::new(BooleanArray::from(success)) as ArrayRef;
        let content_array = Arc::new(StringArray::from(contents)) as ArrayRef;
        let status_array = Arc::new(UInt64Array::from(status_codes)) as ArrayRef;
        let error_array = Arc::new(StringArray::from(errors)) as ArrayRef;
        let duration_array = Arc::new(UInt64Array::from(durations)) as ArrayRef;

        // Create record batch
        let batch = RecordBatch::try_new(
            schema.clone(),
            vec![
                url_array,
                success_array,
                content_array,
                status_array,
                error_array,
                duration_array,
            ],
        )
        .context("Failed to create record batch")?;

        // Write to Parquet
        let file = File::create(path).context("Failed to create output file")?;
        
        let props = WriterProperties::builder()
            .set_compression(self.compression)
            .build();

        let mut writer = ArrowWriter::try_new(file, schema, Some(props))
            .context("Failed to create Parquet writer")?;

        writer
            .write(&batch)
            .context("Failed to write batch")?;

        writer.close().context("Failed to close writer")?;

        let file_size = std::fs::metadata(path)?.len();
        info!(
            "Saved {} records to Parquet ({:.2} MB, GZIP compressed)",
            results.len(),
            file_size as f64 / 1_048_576.0
        );

        Ok(())
    }

    /// Save parsed data to Parquet (for curated results)
    pub fn save_parsed_data<P: AsRef<Path>>(
        &self,
        data: &[ParsedRecord],
        output_path: P,
    ) -> Result<()> {
        let path = output_path.as_ref();
        info!("Saving {} parsed records to Parquet: {:?}", data.len(), path);

        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        let schema = Arc::new(Schema::new(vec![
            Field::new("canonical_id", DataType::Utf8, false),
            Field::new("title", DataType::Utf8, true),
            Field::new("text_length", DataType::UInt64, false),
            Field::new("has_buy_keywords", DataType::Boolean, false),
            Field::new("quality_score", DataType::UInt64, false),
        ]));

        let ids: Vec<&str> = data.iter().map(|r| r.canonical_id.as_str()).collect();
        let titles: Vec<Option<&str>> = data.iter().map(|r| r.title.as_deref()).collect();
        let lengths: Vec<u64> = data.iter().map(|r| r.text_length as u64).collect();
        let buy_keywords: Vec<bool> = data.iter().map(|r| r.has_buy_keywords).collect();
        let quality: Vec<u64> = data.iter().map(|r| r.quality_score as u64).collect();

        let batch = RecordBatch::try_new(
            schema.clone(),
            vec![
                Arc::new(StringArray::from(ids)) as ArrayRef,
                Arc::new(StringArray::from(titles)) as ArrayRef,
                Arc::new(UInt64Array::from(lengths)) as ArrayRef,
                Arc::new(BooleanArray::from(buy_keywords)) as ArrayRef,
                Arc::new(UInt64Array::from(quality)) as ArrayRef,
            ],
        )?;

        let file = File::create(path)?;
        let props = WriterProperties::builder()
            .set_compression(self.compression)
            .build();

        let mut writer = ArrowWriter::try_new(file, schema, Some(props))?;
        writer.write(&batch)?;
        writer.close()?;

        let file_size = std::fs::metadata(path)?.len();
        debug!("Saved parsed data: {:.2} MB", file_size as f64 / 1_048_576.0);

        Ok(())
    }
}

impl Default for ParquetStorage {
    fn default() -> Self {
        Self::new()
    }
}

/// Parsed record structure for curated data
#[derive(Debug, Clone)]
pub struct ParsedRecord {
    pub canonical_id: String,
    pub title: Option<String>,
    pub text_length: usize,
    pub has_buy_keywords: bool,
    pub quality_score: u32,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parallel::DownloadResult;

    #[test]
    fn test_save_results() {
        let storage = ParquetStorage::new();
        
        let results = vec![
            DownloadResult {
                url: "https://example.com".to_string(),
                success: true,
                content: Some("<html>test</html>".to_string()),
                status_code: Some(200),
                error: None,
                duration_ms: 100,
            },
        ];

        let temp_dir = std::env::temp_dir();
        let output_path = temp_dir.join("test_results.parquet");
        
        storage.save_results(&results, &output_path).unwrap();
        assert!(output_path.exists());
        
        std::fs::remove_file(output_path).ok();
    }
}
