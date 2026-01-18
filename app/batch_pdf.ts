import fs from 'fs';
import path from 'path';
import puppeteer, { Browser, Page } from 'puppeteer';

interface ScoreRecord {
  canonical_id: string;
  title: string;
  text_length: number;
  has_buy_keywords: boolean;
  quality_score: number;
  final_score: number;
  errors: string[];
}

interface TopData {
  run_id: string;
  count: number;
  timestamp: string;
  items: ScoreRecord[];
}

interface BatchConfig {
  poolSize: number;
  outputDir: string;
  concurrent: number;
}

/**
 * Browser pool for concurrent PDF generation
 */
class BrowserPool {
  private browsers: Browser[] = [];
  private available: Browser[] = [];
  private poolSize: number;

  constructor(poolSize: number) {
    this.poolSize = poolSize;
  }

  async initialize(): Promise<void> {
    console.log(`🚀 Initializing browser pool with ${this.poolSize} browsers...`);
    
    const launchPromises = Array(this.poolSize)
      .fill(0)
      .map(() => 
        puppeteer.launch({
          headless: true,
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
          ],
        })
      );

    this.browsers = await Promise.all(launchPromises);
    this.available = [...this.browsers];
    console.log(`✓ Browser pool initialized with ${this.browsers.length} browsers`);
  }

  async acquire(): Promise<Browser> {
    while (this.available.length === 0) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    return this.available.pop()!;
  }

  release(browser: Browser): void {
    this.available.push(browser);
  }

  async close(): Promise<void> {
    console.log('🔒 Closing browser pool...');
    await Promise.all(this.browsers.map((b) => b.close()));
    this.browsers = [];
    this.available = [];
    console.log('✓ Browser pool closed');
  }
}

/**
 * Generate PDFs in batch using browser pool
 */
export class BatchPdfGenerator {
  private pool: BrowserPool;
  private config: BatchConfig;

  constructor(config: Partial<BatchConfig> = {}) {
    this.config = {
      poolSize: config.poolSize || 10,
      outputDir: config.outputDir || 'data/reports',
      concurrent: config.concurrent || 10,
    };
    this.pool = new BrowserPool(this.config.poolSize);
  }

  async initialize(): Promise<void> {
    await this.pool.initialize();
  }

  async close(): Promise<void> {
    await this.pool.close();
  }

  /**
   * Generate a single PDF report
   */
  async generatePdf(runId: string, data: TopData): Promise<string> {
    const browser = await this.pool.acquire();

    try {
      const page = await browser.newPage();
      const html = this.generateHtml(data);
      
      await page.setContent(html, { waitUntil: 'networkidle0' });
      
      const outputPath = path.join(this.config.outputDir, `${runId}.pdf`);
      await page.pdf({
        path: outputPath,
        format: 'A4',
        printBackground: true,
        margin: {
          top: '20px',
          right: '20px',
          bottom: '20px',
          left: '20px',
        },
      });

      await page.close();
      return outputPath;
    } finally {
      this.pool.release(browser);
    }
  }

  /**
   * Generate multiple PDFs in parallel
   */
  async generateBatch(runIds: string[], dataDir: string = 'data'): Promise<string[]> {
    console.log(`📊 Starting batch PDF generation for ${runIds.length} reports`);
    const startTime = Date.now();

    // Load all data files
    const dataPromises = runIds.map(async (runId) => {
      const topFile = path.join(dataDir, 'top', `${runId}.json`);
      if (!fs.existsSync(topFile)) {
        throw new Error(`Top file not found: ${topFile}`);
      }
      const data: TopData = JSON.parse(fs.readFileSync(topFile, 'utf-8'));
      return { runId, data };
    });

    const allData = await Promise.all(dataPromises);

    // Generate PDFs concurrently
    const results: string[] = [];
    for (let i = 0; i < allData.length; i += this.config.concurrent) {
      const batch = allData.slice(i, i + this.config.concurrent);
      const batchResults = await Promise.all(
        batch.map(({ runId, data }) => this.generatePdf(runId, data))
      );
      results.push(...batchResults);
      console.log(`  Progress: ${results.length}/${allData.length} PDFs generated`);
    }

    const duration = (Date.now() - startTime) / 1000;
    const avgTime = duration / runIds.length;

    console.log(`✓ Batch PDF generation complete`);
    console.log(`  Total: ${runIds.length} PDFs in ${duration.toFixed(2)}s`);
    console.log(`  Avg: ${(avgTime * 1000).toFixed(1)}ms per PDF`);
    console.log(`  Throughput: ${(runIds.length / duration).toFixed(1)} PDFs/sec`);

    return results;
  }

  /**
   * Generate HTML content for PDF
   */
  private generateHtml(data: TopData): string {
    const itemsHtml = data.items
      .map(
        (item, idx) => `
      <tr>
        <td>${idx + 1}</td>
        <td>${this.escapeHtml(item.title || 'N/A')}</td>
        <td>${item.text_length}</td>
        <td>${item.quality_score.toFixed(1)}</td>
        <td>${item.final_score.toFixed(1)}</td>
        <td>${item.has_buy_keywords ? '✓ Yes' : '✗ No'}</td>
        <td>${item.errors.length === 0 ? 'Clean' : item.errors.join(', ')}</td>
      </tr>
    `
      )
      .join('');

    const timestamp = new Date(data.timestamp).toLocaleString();
    const avgScore = (
      data.items.reduce((a, b) => a + b.final_score, 0) / data.items.length
    ).toFixed(1);

    return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>JARVIX Report - ${data.run_id}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { 
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 20px;
      font-size: 12px;
    }
    h1 { 
      color: #667eea; 
      margin-bottom: 10px;
      font-size: 24px;
    }
    .header { 
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 20px;
      margin-bottom: 20px;
      border-radius: 8px;
    }
    .info-grid { 
      display: grid; 
      grid-template-columns: repeat(4, 1fr);
      gap: 10px;
      margin-bottom: 20px;
      padding: 15px;
      background: #f8f9fa;
      border-radius: 8px;
    }
    .info-card { text-align: center; }
    .info-label { 
      font-size: 10px; 
      color: #666;
      text-transform: uppercase;
      margin-bottom: 5px;
    }
    .info-value { 
      font-size: 16px; 
      font-weight: bold; 
      color: #667eea;
    }
    table { 
      width: 100%; 
      border-collapse: collapse;
      margin-top: 10px;
    }
    th { 
      background: #667eea; 
      color: white; 
      padding: 8px;
      text-align: left;
      font-size: 11px;
    }
    td { 
      padding: 8px;
      border-bottom: 1px solid #e0e0e0;
      font-size: 10px;
    }
    tr:hover { background: #f5f5f5; }
    .footer {
      margin-top: 20px;
      padding-top: 10px;
      border-top: 1px solid #e0e0e0;
      text-align: center;
      color: #666;
      font-size: 10px;
    }
    h2 {
      color: #333;
      margin: 20px 0 10px 0;
      font-size: 16px;
      border-bottom: 2px solid #667eea;
      padding-bottom: 5px;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>🎯 JARVIX v2.0 Report</h1>
    <p>Scalable OSINT & Scoring Engine - Batch PDF Generation</p>
  </div>

  <div class="info-grid">
    <div class="info-card">
      <div class="info-label">Run ID</div>
      <div class="info-value">${this.escapeHtml(data.run_id)}</div>
    </div>
    <div class="info-card">
      <div class="info-label">Items</div>
      <div class="info-value">${data.count}</div>
    </div>
    <div class="info-card">
      <div class="info-label">Timestamp</div>
      <div class="info-value">${timestamp}</div>
    </div>
    <div class="info-card">
      <div class="info-label">Avg Score</div>
      <div class="info-value">${avgScore}</div>
    </div>
  </div>

  <h2>📊 Top Opportunities</h2>
  <table>
    <thead>
      <tr>
        <th>#</th>
        <th>Title</th>
        <th>Length</th>
        <th>Quality</th>
        <th>Score</th>
        <th>Buy Intent</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
      ${itemsHtml}
    </tbody>
  </table>

  <div class="footer">
    <p>Generated by JARVIX v2.0 | Phase 6: Scalability | Batch PDF Generation</p>
  </div>
</body>
</html>`;
  }

  private escapeHtml(text: string): string {
    const map: { [key: string]: string } = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;',
    };
    return text.replace(/[&<>"']/g, (m) => map[m]);
  }
}

// Main execution for CLI usage
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage:');
    console.error('  Single: node batch_pdf.ts <run_id> [data_dir]');
    console.error('  Batch:  node batch_pdf.ts --batch <run_id1> <run_id2> ... [--data-dir=path]');
    process.exit(1);
  }

  (async () => {
    const generator = new BatchPdfGenerator({
      poolSize: 10,
      outputDir: 'data/reports',
      concurrent: 10,
    });

    try {
      await generator.initialize();

      if (args[0] === '--batch') {
        // Batch mode
        const dataDirArg = args.find(a => a.startsWith('--data-dir='));
        const dataDir = dataDirArg ? dataDirArg.split('=')[1] : 'data';
        const runIds = args.filter(a => !a.startsWith('--') && a !== '--batch');

        const results = await generator.generateBatch(runIds, dataDir);
        console.log('\n✅ Batch PDF generation completed!');
        console.log(`Generated ${results.length} PDF reports`);
      } else {
        // Single mode
        const runId = args[0];
        const dataDir = args[1] || 'data';
        const topFile = path.join(dataDir, 'top', `${runId}.json`);
        
        if (!fs.existsSync(topFile)) {
          throw new Error(`Top file not found: ${topFile}`);
        }

        const data: TopData = JSON.parse(fs.readFileSync(topFile, 'utf-8'));
        const outputPath = await generator.generatePdf(runId, data);
        
        console.log('\n✅ PDF generation completed!');
        console.log(`Output: ${outputPath}`);
      }
    } finally {
      await generator.close();
    }
  })().catch((err) => {
    console.error('❌ Error:', err.message);
    process.exit(1);
  });
}

export { BatchPdfGenerator, BatchConfig };
