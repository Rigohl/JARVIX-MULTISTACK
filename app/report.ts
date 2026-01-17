import fs from 'fs';
import path from 'path';

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

async function generateReport(runId: string, outputDir = 'data'): Promise<string> {
  const topFile = path.join(outputDir, 'top', `${runId}.json`);
  
  if (!fs.existsSync(topFile)) {
    throw new Error(`Top file not found: ${topFile}`);
  }

  console.log(`📋 Generating report for run: ${runId}`);

  const topData: TopData = JSON.parse(fs.readFileSync(topFile, 'utf-8'));
  const reportFile = path.join(outputDir, 'reports', `${runId}.html`);

  // Ensure directory exists
  fs.mkdirSync(path.dirname(reportFile), { recursive: true });

  const html = generateHtml(topData);
  fs.writeFileSync(reportFile, html);

  console.log(`✓ Report generated: ${reportFile}`);
  return reportFile;
}

function generateHtml(data: TopData): string {
  const itemsHtml = data.items
    .map(
      (item, idx) => `
    <tr>
      <td>${idx + 1}</td>
      <td>${escapeHtml(item.title || 'N/A')}</td>
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

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>JARVIX MVP Report - ${data.run_id}</title>
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
      max-width: 1200px;
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
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
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
      font-size: 0.9em;
      text-transform: uppercase;
      margin-bottom: 5px;
    }
    .info-value {
      font-size: 1.5em;
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
    }
    td {
      padding: 12px;
      border-bottom: 1px solid #e0e0e0;
    }
    tr:hover {
      background: #f5f5f5;
    }
    .score-high {
      color: #4caf50;
      font-weight: bold;
    }
    .score-medium {
      color: #ff9800;
      font-weight: bold;
    }
    .score-low {
      color: #f44336;
      font-weight: bold;
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
    .score-badge {
      display: inline-block;
      padding: 4px 8px;
      border-radius: 20px;
      font-size: 0.85em;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>🎯 JARVIX MVP Report</h1>
      <p>Análisis de Oportunidades - Motor Local de Scoring</p>
    </header>

    <div class="info-grid">
      <div class="info-card">
        <div class="info-label">Run ID</div>
        <div class="info-value">${escapeHtml(data.run_id)}</div>
      </div>
      <div class="info-card">
        <div class="info-label">Items Procesados</div>
        <div class="info-value">${data.count}</div>
      </div>
      <div class="info-card">
        <div class="info-label">Timestamp</div>
        <div class="info-value">${timestamp}</div>
      </div>
      <div class="info-card">
        <div class="info-label">Score Promedio</div>
        <div class="info-value">${(data.items.reduce((a, b) => a + b.final_score, 0) / data.items.length).toFixed(1)}</div>
      </div>
    </div>

    <main>
      <h2>📊 Top Oportunidades</h2>
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Título</th>
            <th>Longitud Texto</th>
            <th>Quality</th>
            <th>Score Final</th>
            <th>Buy Intent</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          ${itemsHtml}
        </tbody>
      </table>

      <div class="recommendations">
        <h3>💡 Acciones Recomendadas</h3>
        <ul>
          <li><strong>Verificación Manual:</strong> Revisar los top 3 items con mayor score para validar calidad</li>
          <li><strong>Refinamiento de Keywords:</strong> Actualizar data/paywall_keywords.txt con nuevos patrones detectados</li>
          <li><strong>Expansión de Allowlist:</strong> Agregar dominios prometedores a data/allowed_domains.txt</li>
          <li><strong>Iteración:</strong> Ejecutar run_mvp.ps1 nuevamente con más URLs de seeds</li>
          <li><strong>Análisis de Errores:</strong> Revisar data/invalid/${escapeHtml(data.run_id)}.jsonl para patrones</li>
        </ul>
      </div>

      <h2>📈 Signals Detectadas</h2>
      <table>
        <thead>
          <tr>
            <th>Signal</th>
            <th>Descripción</th>
            <th>Detección</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>Buy Keywords</strong></td>
            <td>Presencia de palabras clave de compra</td>
            <td>${data.items.filter(i => i.has_buy_keywords).length} / ${data.count}</td>
          </tr>
          <tr>
            <td><strong>Clean Records</strong></td>
            <td>Items sin errores de validación</td>
            <td>${data.items.filter(i => i.errors.length === 0).length} / ${data.count}</td>
          </tr>
          <tr>
            <td><strong>High Quality</strong></td>
            <td>Quality score > 80</td>
            <td>${data.items.filter(i => i.quality_score > 80).length} / ${data.count}</td>
          </tr>
        </tbody>
      </table>
    </main>

    <footer>
      <p>Generado por JARVIX MVP | Local OSINT & Scoring Engine | 100% Local, Sin APIs Pagadas</p>
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
    console.error('Usage: node report.ts <run_id> [output_dir]');
    process.exit(1);
  }

  generateReport(runId, outputDir)
    .then(() => {
      console.log('\n✅ Report generation completed!');
      process.exit(0);
    })
    .catch((err) => {
      console.error('❌ Error:', err.message);
      process.exit(1);
    });
}

export { generateReport };
