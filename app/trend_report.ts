import fs from 'fs';
import path from 'path';

interface ScoreRecord {
  canonical_id: string;
  url?: string;
  title: string;
  text_length: number;
  has_buy_keywords: boolean;
  quality_score: number;
  final_score: number;
  errors: string[];
}

interface TrendData {
  url: string;
  trend_status: string;
  current_score: number;
  previous_score: number | null;
  change_percent: number;
  forecast_30day: number | null;
  confidence: number;
  data_points: number;
}

interface TrendsReport {
  run_id: string;
  analysis_date: string;
  total_urls: number;
  improved_count: number;
  trends: TrendData[];
}

interface TopData {
  run_id: string;
  count: number;
  timestamp: string;
  items: ScoreRecord[];
}

async function generateTrendReport(runId: string, outputDir = 'data'): Promise<string> {
  const topFile = path.join(outputDir, 'top', `${runId}.json`);
  const trendsFile = path.join(outputDir, 'reports', `${runId}_trends.json`);
  
  if (!fs.existsSync(topFile)) {
    throw new Error(`Top file not found: ${topFile}`);
  }

  console.log(`📋 Generating trend report for run: ${runId}`);

  const topData: TopData = JSON.parse(fs.readFileSync(topFile, 'utf-8'));
  
  // Load trends data if available
  let trendsData: TrendsReport | null = null;
  if (fs.existsSync(trendsFile)) {
    trendsData = JSON.parse(fs.readFileSync(trendsFile, 'utf-8'));
    console.log(`✓ Loaded trends data: ${trendsData.trends.length} trends`);
  } else {
    console.log(`⚠️  No trends data found at ${trendsFile}`);
  }

  const reportFile = path.join(outputDir, 'reports', `${runId}_with_trends.html`);

  // Ensure directory exists
  fs.mkdirSync(path.dirname(reportFile), { recursive: true });

  const html = generateTrendHtml(topData, trendsData);
  fs.writeFileSync(reportFile, html);

  console.log(`✓ Trend report generated: ${reportFile}`);
  return reportFile;
}

function getTrendBadge(status: string): string {
  const badges: { [key: string]: string } = {
    'IMPROVED': '<span style="background: #4CAF50; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.85em;">📈 IMPROVED</span>',
    'DECLINED': '<span style="background: #f44336; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.85em;">📉 DECLINED</span>',
    'STABLE': '<span style="background: #2196F3; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.85em;">➡️ STABLE</span>',
    'NEW': '<span style="background: #9E9E9E; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.85em;">🆕 NEW</span>',
  };
  return badges[status] || status;
}

function generateSparkline(dataPoints: number, changePercent: number): string {
  // Simple ASCII-art style sparkline
  if (dataPoints < 2) {
    return '▬';
  }
  
  if (changePercent > 20) {
    return '▁▂▃▅▆▇█'; // Strong upward
  } else if (changePercent > 10) {
    return '▂▃▄▅▆'; // Moderate upward
  } else if (changePercent < -20) {
    return '█▇▆▅▃▂▁'; // Strong downward
  } else if (changePercent < -10) {
    return '▆▅▄▃▂'; // Moderate downward
  } else {
    return '▄▄▄▄▄'; // Stable
  }
}

function generateTrendHtml(data: TopData, trends: TrendsReport | null): string {
  // Create a map of trends by URL
  const trendMap = new Map<string, TrendData>();
  if (trends) {
    trends.trends.forEach(t => {
      trendMap.set(t.url, t);
    });
  }

  const itemsHtml = data.items
    .map((item, idx) => {
      const url = item.url || item.canonical_id;
      const trend = trendMap.get(url);
      
      let trendCell = '<td>N/A</td>';
      let changeCell = '<td>N/A</td>';
      let forecastCell = '<td>N/A</td>';
      
      if (trend) {
        trendCell = `<td>${getTrendBadge(trend.trend_status)}</td>`;
        
        if (trend.previous_score !== null) {
          const changeColor = trend.change_percent > 0 ? '#4CAF50' : 
                              trend.change_percent < 0 ? '#f44336' : '#666';
          const arrow = trend.change_percent > 0 ? '↑' : 
                        trend.change_percent < 0 ? '↓' : '→';
          changeCell = `<td style="color: ${changeColor}; font-weight: bold;">
            ${arrow} ${trend.change_percent.toFixed(1)}%<br>
            <span style="font-size: 0.9em; font-family: monospace;">${generateSparkline(trend.data_points, trend.change_percent)}</span>
          </td>`;
        } else {
          changeCell = '<td>—</td>';
        }
        
        if (trend.forecast_30day !== null) {
          forecastCell = `<td>${trend.forecast_30day.toFixed(1)}<br>
            <span style="font-size: 0.8em; color: #666;">(${(trend.confidence * 100).toFixed(0)}% conf.)</span>
          </td>`;
        } else {
          forecastCell = '<td>—</td>';
        }
      }
      
      return `
    <tr>
      <td>${idx + 1}</td>
      <td>${escapeHtml(item.title || 'N/A')}</td>
      <td>${item.final_score.toFixed(1)}</td>
      ${trendCell}
      ${changeCell}
      ${forecastCell}
      <td>${item.has_buy_keywords ? '✓' : '✗'}</td>
    </tr>
  `;
    })
    .join('');

  const timestamp = new Date(data.timestamp).toLocaleString();

  // Trend summary stats
  let trendSummary = '';
  if (trends) {
    const newCount = trends.trends.filter(t => t.trend_status === 'NEW').length;
    const improvedCount = trends.trends.filter(t => t.trend_status === 'IMPROVED').length;
    const declinedCount = trends.trends.filter(t => t.trend_status === 'DECLINED').length;
    const stableCount = trends.trends.filter(t => t.trend_status === 'STABLE').length;
    
    trendSummary = `
      <div class="info-card">
        <div class="info-label">🆕 New</div>
        <div class="info-value">${newCount}</div>
      </div>
      <div class="info-card">
        <div class="info-label">📈 Improved</div>
        <div class="info-value" style="color: #4CAF50;">${improvedCount}</div>
      </div>
      <div class="info-card">
        <div class="info-label">📉 Declined</div>
        <div class="info-value" style="color: #f44336;">${declinedCount}</div>
      </div>
      <div class="info-card">
        <div class="info-label">➡️ Stable</div>
        <div class="info-value" style="color: #2196F3;">${stableCount}</div>
      </div>
    `;
  }

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>JARVIX Trend Report - ${data.run_id}</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 20px;
    }
    .container {
      max-width: 1400px;
      margin: 0 auto;
      background: white;
      border-radius: 10px;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
      overflow: hidden;
    }
    header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px 20px;
      text-align: center;
    }
    header h1 {
      font-size: 2.5em;
      margin-bottom: 10px;
    }
    header p {
      opacity: 0.9;
      font-size: 1.1em;
    }
    .info-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 15px;
      padding: 20px;
      background: #f8f9fa;
      border-bottom: 1px solid #e0e0e0;
    }
    .info-card {
      text-align: center;
      padding: 10px;
    }
    .info-label {
      color: #666;
      font-size: 0.85em;
      text-transform: uppercase;
      margin-bottom: 5px;
    }
    .info-value {
      font-size: 1.4em;
      font-weight: bold;
      color: #667eea;
    }
    main {
      padding: 30px 20px;
    }
    h2 {
      color: #333;
      margin: 30px 0 20px 0;
      border-bottom: 2px solid #667eea;
      padding-bottom: 10px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 15px;
    }
    th {
      background: #667eea;
      color: white;
      padding: 12px;
      text-align: left;
      font-weight: 600;
      font-size: 0.9em;
    }
    td {
      padding: 12px;
      border-bottom: 1px solid #e0e0e0;
      font-size: 0.9em;
    }
    tr:hover {
      background: #f5f5f5;
    }
    .alert-box {
      background: #fff3cd;
      border-left: 4px solid #ffc107;
      padding: 15px;
      margin: 20px 0;
      border-radius: 4px;
    }
    .alert-box.success {
      background: #d4edda;
      border-left-color: #28a745;
    }
    .recommendations {
      background: #e3f2fd;
      border-left: 4px solid #2196f3;
      padding: 15px;
      margin-top: 20px;
      border-radius: 4px;
    }
    .recommendations h3 {
      color: #1976d2;
      margin-bottom: 10px;
    }
    .recommendations ul {
      margin-left: 20px;
    }
    .recommendations li {
      margin-bottom: 8px;
      line-height: 1.6;
    }
    footer {
      background: #f8f9fa;
      padding: 20px;
      text-align: center;
      color: #666;
      border-top: 1px solid #e0e0e0;
      font-size: 0.9em;
    }
    .legend {
      display: flex;
      gap: 20px;
      flex-wrap: wrap;
      margin: 15px 0;
      font-size: 0.9em;
    }
    .legend-item {
      display: flex;
      align-items: center;
      gap: 5px;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>📊 JARVIX Trend Analysis Report</h1>
      <p>Week-over-Week Temporal Trend Detection</p>
    </header>

    <div class="info-grid">
      <div class="info-card">
        <div class="info-label">Run ID</div>
        <div class="info-value">${escapeHtml(data.run_id)}</div>
      </div>
      <div class="info-card">
        <div class="info-label">Total URLs</div>
        <div class="info-value">${data.count}</div>
      </div>
      <div class="info-card">
        <div class="info-label">Timestamp</div>
        <div class="info-value">${timestamp}</div>
      </div>
      <div class="info-card">
        <div class="info-label">Avg Score</div>
        <div class="info-value">${(data.items.reduce((a, b) => a + b.final_score, 0) / data.items.length).toFixed(1)}</div>
      </div>
      ${trendSummary}
    </div>

    <main>
      ${trends && trends.improved_count > 0 ? `
      <div class="alert-box success">
        <strong>🔔 Alert:</strong> ${trends.improved_count} URL(s) with significant improvements (&gt;20%)!
      </div>
      ` : ''}

      <h2>📈 Top Opportunities with Trends</h2>
      
      <div class="legend">
        <div class="legend-item">
          <strong>Sparklines:</strong>
        </div>
        <div class="legend-item">▁▂▃▅▆▇█ = Strong Growth</div>
        <div class="legend-item">▄▄▄▄▄ = Stable</div>
        <div class="legend-item">█▇▆▅▃▂▁ = Decline</div>
      </div>

      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Title</th>
            <th>Score</th>
            <th>Trend Status</th>
            <th>Change (7d)</th>
            <th>Forecast (30d)</th>
            <th>Buy Intent</th>
          </tr>
        </thead>
        <tbody>
          ${itemsHtml}
        </tbody>
      </table>

      <div class="recommendations">
        <h3>💡 Recommended Actions</h3>
        <ul>
          <li><strong>High Priority:</strong> Focus on URLs marked as IMPROVED with &gt;20% growth</li>
          <li><strong>Monitor:</strong> Track STABLE URLs for potential opportunities</li>
          <li><strong>Investigate:</strong> Review DECLINED trends to identify issues</li>
          <li><strong>Forecast Confidence:</strong> Higher confidence (&gt;70%) indicates more reliable predictions</li>
          <li><strong>Next Analysis:</strong> Schedule weekly re-analysis to track ongoing trends</li>
        </ul>
      </div>

      ${trends ? `
      <h2>📊 Trend Distribution</h2>
      <table>
        <thead>
          <tr>
            <th>Status</th>
            <th>Count</th>
            <th>Percentage</th>
            <th>Description</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>${getTrendBadge('IMPROVED')}</td>
            <td>${trends.trends.filter(t => t.trend_status === 'IMPROVED').length}</td>
            <td>${((trends.trends.filter(t => t.trend_status === 'IMPROVED').length / trends.total_urls) * 100).toFixed(1)}%</td>
            <td>Score increased &gt;10% compared to 7 days ago</td>
          </tr>
          <tr>
            <td>${getTrendBadge('DECLINED')}</td>
            <td>${trends.trends.filter(t => t.trend_status === 'DECLINED').length}</td>
            <td>${((trends.trends.filter(t => t.trend_status === 'DECLINED').length / trends.total_urls) * 100).toFixed(1)}%</td>
            <td>Score decreased &gt;10% compared to 7 days ago</td>
          </tr>
          <tr>
            <td>${getTrendBadge('STABLE')}</td>
            <td>${trends.trends.filter(t => t.trend_status === 'STABLE').length}</td>
            <td>${((trends.trends.filter(t => t.trend_status === 'STABLE').length / trends.total_urls) * 100).toFixed(1)}%</td>
            <td>Score changed within ±10%</td>
          </tr>
          <tr>
            <td>${getTrendBadge('NEW')}</td>
            <td>${trends.trends.filter(t => t.trend_status === 'NEW').length}</td>
            <td>${((trends.trends.filter(t => t.trend_status === 'NEW').length / trends.total_urls) * 100).toFixed(1)}%</td>
            <td>First time analyzing this URL</td>
          </tr>
        </tbody>
      </table>
      ` : '<p>No trend data available. Run trend analysis first: <code>julia science/trends.jl &lt;run_id&gt;</code></p>'}
    </main>

    <footer>
      <p>Generated by JARVIX Phase 3: Temporal Trend Detection | Week-over-Week Analysis</p>
      <p>For more information, see science/trends.jl and weekly_trends.jl</p>
    </footer>
  </div>
</body>
</html>`;
}

function escapeHtml(text: string): string {
  const map: { [key: string]: string } = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
  };
  return text.replace(/[&<>"']/g, (m) => map[m]);
}

// Main execution
if (require.main === module) {
  const runId = process.argv[2];
  const outputDir = process.argv[3] || 'data';

  if (!runId) {
    console.error('Usage: node trend_report.ts <run_id> [output_dir]');
    process.exit(1);
  }

  generateTrendReport(runId, outputDir)
    .then(() => {
      console.log('\n✅ Trend report generation completed!');
      process.exit(0);
    })
    .catch((err) => {
      console.error('❌ Error:', err.message);
      process.exit(1);
    });
}

export { generateTrendReport };
