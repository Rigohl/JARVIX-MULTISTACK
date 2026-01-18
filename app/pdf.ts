import fs from 'fs';
import path from 'path';
import PDFDocument from 'pdfkit';
import { ChartJSNodeCanvas } from 'chartjs-node-canvas';

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

interface PDFOptions {
  outputDir?: string;
  includeCharts?: boolean;
  pageSize?: 'A4' | 'LETTER';
}

interface ActionRecommendation {
  action: 'BUY' | 'MONITOR' | 'SKIP';
  color: string;
  confidence: number;
  reason: string;
}

/**
 * Determine recommended action based on score
 */
function getRecommendedAction(score: number, hasKeywords: boolean): ActionRecommendation {
  if (score > 75) {
    return {
      action: 'BUY',
      color: '#4CAF50',
      confidence: hasKeywords ? 0.95 : 0.85,
      reason: hasKeywords ? 'High quality score with buy intent' : 'High quality score',
    };
  } else if (score > 50) {
    return {
      action: 'MONITOR',
      color: '#FF9800',
      confidence: hasKeywords ? 0.75 : 0.70,
      reason: hasKeywords ? 'Medium potential with buy signals' : 'Medium potential, requires evaluation',
    };
  } else {
    return {
      action: 'SKIP',
      color: '#F44336',
      confidence: 0.85,
      reason: 'Low quality or insufficient signals',
    };
  }
}

/**
 * Generate score distribution chart
 */
async function generateScoreDistributionChart(items: ScoreRecord[]): Promise<Buffer> {
  const width = 600;
  const height = 400;
  const chartJSNodeCanvas = new ChartJSNodeCanvas({ width, height });

  // Create score ranges
  const ranges = [
    { label: '0-25', min: 0, max: 25, color: '#F44336' },
    { label: '26-50', min: 26, max: 50, color: '#FF9800' },
    { label: '51-75', min: 51, max: 75, color: '#FFC107' },
    { label: '76-100', min: 76, max: 100, color: '#4CAF50' },
  ];

  const counts = ranges.map((range) => {
    return items.filter((item) => item.final_score >= range.min && item.final_score <= range.max)
      .length;
  });

  const configuration = {
    type: 'bar' as const,
    data: {
      labels: ranges.map((r) => r.label),
      datasets: [
        {
          label: 'Number of Opportunities',
          data: counts,
          backgroundColor: ranges.map((r) => r.color),
          borderColor: ranges.map((r) => r.color),
          borderWidth: 1,
        },
      ],
    },
    options: {
      responsive: false,
      plugins: {
        title: {
          display: true,
          text: 'Score Distribution',
          font: {
            size: 18,
          },
        },
        legend: {
          display: false,
        },
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            stepSize: 1,
          },
        },
      },
    },
  };

  return await chartJSNodeCanvas.renderToBuffer(configuration);
}

/**
 * Generate action recommendations chart
 */
async function generateActionsChart(items: ScoreRecord[]): Promise<Buffer> {
  const width = 600;
  const height = 400;
  const chartJSNodeCanvas = new ChartJSNodeCanvas({ width, height });

  // Count actions
  const actions = items.map((item) => getRecommendedAction(item.final_score, item.has_buy_keywords));
  const buys = actions.filter((a) => a.action === 'BUY').length;
  const monitors = actions.filter((a) => a.action === 'MONITOR').length;
  const skips = actions.filter((a) => a.action === 'SKIP').length;

  const configuration = {
    type: 'pie' as const,
    data: {
      labels: ['BUY', 'MONITOR', 'SKIP'],
      datasets: [
        {
          data: [buys, monitors, skips],
          backgroundColor: ['#4CAF50', '#FF9800', '#F44336'],
          borderColor: ['#fff', '#fff', '#fff'],
          borderWidth: 2,
        },
      ],
    },
    options: {
      responsive: false,
      plugins: {
        title: {
          display: true,
          text: 'Recommended Actions',
          font: {
            size: 18,
          },
        },
        legend: {
          position: 'bottom' as const,
        },
      },
    },
  };

  return await chartJSNodeCanvas.renderToBuffer(configuration);
}

/**
 * Main PDF generation function
 */
export async function generatePDF(
  runId: string,
  options: PDFOptions = {}
): Promise<string> {
  const outputDir = options.outputDir || 'data';
  const includeCharts = options.includeCharts !== false;
  const pageSize = options.pageSize || 'A4';

  // Load data
  const topFile = path.join(outputDir, 'top', `${runId}.json`);
  if (!fs.existsSync(topFile)) {
    throw new Error(`Top file not found: ${topFile}`);
  }

  console.log(`📄 Generating PDF for run: ${runId}`);

  const topData: TopData = JSON.parse(fs.readFileSync(topFile, 'utf-8'));
  const pdfPath = path.join(outputDir, 'reports', `${runId}.pdf`);

  // Ensure directory exists
  fs.mkdirSync(path.dirname(pdfPath), { recursive: true });

  // Create PDF document
  const doc = new PDFDocument({ size: pageSize, margin: 50 });
  const stream = fs.createWriteStream(pdfPath);
  doc.pipe(stream);

  // ============ COVER PAGE ============
  doc
    .fillColor('#667eea')
    .fontSize(36)
    .font('Helvetica-Bold')
    .text('JARVIX REPORT', 50, 100, { align: 'center' });

  doc
    .fillColor('#764ba2')
    .fontSize(24)
    .text('Professional Intelligence Analysis', { align: 'center' });

  doc.moveDown(3);

  // Metadata box
  const boxY = 250;
  doc
    .rect(100, boxY, doc.page.width - 200, 200)
    .fillAndStroke('#f8f9fa', '#667eea');

  doc
    .fillColor('#333')
    .fontSize(14)
    .font('Helvetica-Bold')
    .text('Run ID:', 120, boxY + 20);
  doc
    .font('Helvetica')
    .text(topData.run_id, 200, boxY + 20);

  doc
    .font('Helvetica-Bold')
    .text('Date:', 120, boxY + 50);
  doc
    .font('Helvetica')
    .text(new Date(topData.timestamp).toLocaleString(), 200, boxY + 50);

  doc
    .font('Helvetica-Bold')
    .text('Records:', 120, boxY + 80);
  doc
    .font('Helvetica')
    .text(topData.count.toString(), 200, boxY + 80);

  const avgScore = topData.items.length > 0 
    ? topData.items.reduce((a, b) => a + b.final_score, 0) / topData.items.length 
    : 0;
  doc
    .font('Helvetica-Bold')
    .text('Avg Score:', 120, boxY + 110);
  doc
    .font('Helvetica')
    .text(avgScore.toFixed(1), 200, boxY + 110);

  const highConfidence = topData.items.filter((i) => i.final_score > 75).length;
  doc
    .font('Helvetica-Bold')
    .text('High Confidence:', 120, boxY + 140);
  doc
    .font('Helvetica')
    .fillColor('#4CAF50')
    .text(`${highConfidence} opportunities`, 200, boxY + 140);

  // Footer
  doc
    .fillColor('#666')
    .fontSize(10)
    .text('Generated by JARVIX - Local OSINT & Scoring Engine', 50, doc.page.height - 100, {
      align: 'center',
    });

  // ============ EXECUTIVE SUMMARY ============
  doc.addPage();

  doc
    .fillColor('#667eea')
    .fontSize(24)
    .font('Helvetica-Bold')
    .text('Executive Summary', 50, 50);

  doc.moveDown(1);

  // Top 3 opportunities
  doc
    .fillColor('#333')
    .fontSize(16)
    .font('Helvetica-Bold')
    .text('Top Opportunities:', 50);

  doc.moveDown(0.5);
  doc.fontSize(12).font('Helvetica');

  const top3 = topData.items.slice(0, 3);
  top3.forEach((item, idx) => {
    const action = getRecommendedAction(item.final_score, item.has_buy_keywords);
    doc
      .fillColor(action.color)
      .font('Helvetica-Bold')
      .text(`${idx + 1}. ${action.action}`, 50, doc.y, { continued: true })
      .fillColor('#333')
      .font('Helvetica')
      .text(` - ${item.title.substring(0, 60)}...`, { continued: false });

    doc.fontSize(10).text(`   Score: ${item.final_score.toFixed(1)} | ${action.reason}`, 70);
    doc.moveDown(0.5);
    doc.fontSize(12);
  });

  doc.moveDown(1);

  // Key insights
  doc
    .fillColor('#333')
    .fontSize(16)
    .font('Helvetica-Bold')
    .text('Key Insights:', 50);

  doc.moveDown(0.5);
  doc.fontSize(11).font('Helvetica');

  const buyCount = topData.items.filter(
    (i) => getRecommendedAction(i.final_score, i.has_buy_keywords).action === 'BUY'
  ).length;
  const monitorCount = topData.items.filter(
    (i) => getRecommendedAction(i.final_score, i.has_buy_keywords).action === 'MONITOR'
  ).length;
  const skipCount = topData.items.filter(
    (i) => getRecommendedAction(i.final_score, i.has_buy_keywords).action === 'SKIP'
  ).length;

  doc.fillColor('#4CAF50').text(`• ${buyCount} HIGH PRIORITY opportunities (immediate action)`, 60);
  doc.fillColor('#FF9800').text(`• ${monitorCount} MEDIUM PRIORITY opportunities (evaluation needed)`, 60);
  doc.fillColor('#F44336').text(`• ${skipCount} LOW PRIORITY opportunities (can be skipped)`, 60);

  doc.moveDown(1);

  const withKeywords = topData.items.filter((i) => i.has_buy_keywords).length;
  const cleanRecords = topData.items.filter((i) => i.errors.length === 0).length;

  doc
    .fillColor('#333')
    .text(`• ${withKeywords} opportunities have buy intent signals`, 60);
  doc.text(`• ${cleanRecords} records passed all quality checks`, 60);
  
  const avgQualityScore = topData.items.length > 0 
    ? topData.items.reduce((a, b) => a + b.quality_score, 0) / topData.items.length 
    : 0;
  doc.text(`• Average quality score: ${avgQualityScore.toFixed(1)}/100`, 60);

  // ============ TOP-10 TABLE ============
  doc.addPage();

  doc
    .fillColor('#667eea')
    .fontSize(20)
    .font('Helvetica-Bold')
    .text('Top 10 Opportunities & Actions', 50, 50);

  doc.moveDown(1);

  // Table header
  let tableY = doc.y;
  const colX = [50, 90, 280, 340, 400, 470];
  const rowHeight = 40;

  // Header background
  doc.rect(50, tableY, doc.page.width - 100, 25).fill('#667eea');

  doc
    .fillColor('#fff')
    .fontSize(10)
    .font('Helvetica-Bold')
    .text('#', colX[0], tableY + 8, { width: 30 })
    .text('Action', colX[1], tableY + 8, { width: 180 })
    .text('Score', colX[2], tableY + 8, { width: 50 })
    .text('Quality', colX[3], tableY + 8, { width: 50 })
    .text('Keywords', colX[4], tableY + 8, { width: 60 })
    .text('Status', colX[5], tableY + 8, { width: 70 });

  tableY += 25;

  // Table rows
  const top10 = topData.items.slice(0, 10);
  top10.forEach((item, idx) => {
    const action = getRecommendedAction(item.final_score, item.has_buy_keywords);

    // Alternate row background
    if (idx % 2 === 0) {
      doc.rect(50, tableY, doc.page.width - 100, rowHeight).fill('#f8f9fa');
    }

    doc.fillColor('#333').fontSize(9).font('Helvetica');

    // Row content
    doc.text(`${idx + 1}`, colX[0], tableY + 5, { width: 30 });

    doc
      .fillColor(action.color)
      .font('Helvetica-Bold')
      .text(action.action, colX[1], tableY + 5, { width: 60 });

    doc
      .fillColor('#333')
      .font('Helvetica')
      .fontSize(8)
      .text(item.title.substring(0, 80) + (item.title.length > 80 ? '...' : ''), colX[1], tableY + 18, { width: 180 });

    doc.fontSize(9);
    doc.text(item.final_score.toFixed(1), colX[2], tableY + 5, { width: 50 });
    doc.text(item.quality_score.toFixed(0), colX[3], tableY + 5, { width: 50 });
    doc.text(item.has_buy_keywords ? '✓' : '✗', colX[4], tableY + 5, { width: 60 });
    doc.text(item.errors.length === 0 ? 'Clean' : 'Issues', colX[5], tableY + 5, { width: 70 });

    tableY += rowHeight;

    // Add new page if needed
    if (tableY > doc.page.height - 100 && idx < top10.length - 1) {
      doc.addPage();
      tableY = 50;
    }
  });

  // ============ CHARTS ============
  if (includeCharts) {
    doc.addPage();

    doc
      .fillColor('#667eea')
      .fontSize(20)
      .font('Helvetica-Bold')
      .text('Visual Analytics', 50, 50);

    doc.moveDown(1);

    try {
      // Score distribution chart
      const scoreChart = await generateScoreDistributionChart(topData.items);
      doc.image(scoreChart, 50, doc.y, { width: 500 });

      doc.moveDown(15);

      // Actions chart
      const actionsChart = await generateActionsChart(topData.items);
      if (doc.y > doc.page.height - 450) {
        doc.addPage();
      }
      doc.image(actionsChart, 50, doc.y, { width: 500 });
    } catch (error) {
      console.warn('Warning: Could not generate charts:', error);
      doc.fontSize(12).fillColor('#666').text('Charts could not be generated.', 50);
    }
  }

  // ============ RECOMMENDATIONS PAGE ============
  doc.addPage();

  doc
    .fillColor('#667eea')
    .fontSize(20)
    .font('Helvetica-Bold')
    .text('Recommended Actions', 50, 50);

  doc.moveDown(1);

  doc
    .fillColor('#333')
    .fontSize(14)
    .font('Helvetica-Bold')
    .text('Next Steps:', 50);

  doc.moveDown(0.5);
  doc.fontSize(11).font('Helvetica');

  const recommendations = [
    'Review and validate the top 3 BUY opportunities manually',
    'Contact stakeholders for MONITOR opportunities to gather more data',
    'Update keyword database with new patterns detected in this run',
    'Add high-performing domains to the allowlist for future runs',
    'Schedule follow-up analysis in 7 days to track trends',
    'Export detailed data for further analysis if needed',
  ];

  recommendations.forEach((rec, idx) => {
    doc.fillColor('#333').text(`${idx + 1}. ${rec}`, 60);
    doc.moveDown(0.3);
  });

  doc.moveDown(1);

  doc
    .fontSize(14)
    .font('Helvetica-Bold')
    .text('Action Priority Matrix:', 50);

  doc.moveDown(0.5);
  doc.fontSize(11).font('Helvetica');

  doc.fillColor('#4CAF50').text('● BUY (High Priority)', 60, doc.y, { continued: true });
  doc.fillColor('#333').text(' - Immediate action required, high confidence', { continued: false });

  doc.moveDown(0.3);

  doc.fillColor('#FF9800').text('● MONITOR (Medium Priority)', 60, doc.y, { continued: true });
  doc.fillColor('#333').text(' - Evaluate and track, moderate confidence', { continued: false });

  doc.moveDown(0.3);

  doc.fillColor('#F44336').text('● SKIP (Low Priority)', 60, doc.y, { continued: true });
  doc.fillColor('#333').text(' - Can be deprioritized, low confidence', { continued: false });

  // Footer
  doc
    .fillColor('#666')
    .fontSize(9)
    .text(
      `Report generated on ${new Date().toLocaleString()} | JARVIX v2.0`,
      50,
      doc.page.height - 50,
      { align: 'center' }
    );

  // Finalize PDF
  doc.end();

  return new Promise((resolve, reject) => {
    stream.on('finish', () => {
      console.log(`✓ PDF generated: ${pdfPath}`);
      const stats = fs.statSync(pdfPath);
      console.log(`  File size: ${(stats.size / 1024).toFixed(1)} KB`);
      resolve(pdfPath);
    });

    stream.on('error', reject);
  });
}

// Main execution
if (require.main === module) {
  const runId = process.argv[2];
  const outputDir = process.argv[3] || 'data';
  const pageSize = (process.argv[4] as 'A4' | 'LETTER') || 'A4';

  if (!runId) {
    console.error('Usage: npx ts-node app/pdf.ts <run_id> [output_dir] [page_size]');
    console.error('  run_id: The run identifier to generate PDF for');
    console.error('  output_dir: Data directory (default: data)');
    console.error('  page_size: A4 or LETTER (default: A4)');
    process.exit(1);
  }

  const startTime = Date.now();

  generatePDF(runId, { outputDir, pageSize, includeCharts: true })
    .then(() => {
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
      console.log(`\n✅ PDF generation completed in ${elapsed}s`);
      process.exit(0);
    })
    .catch((err) => {
      console.error('❌ Error:', err.message);
      process.exit(1);
    });
}
