# JARVIX-MULTISTACK - MVP ✅

**MVP end-to-end**: ingesta → logging → curación → scoring → **actions** → reporte
**Stack**: Rust 1.92+ | Julia 1.12+ | TypeScript 5.9+ | PowerShell 7+ | SQLite 3.47+
**Status**: ✅ Completado y testeado end-to-end con Phase 1 Actions Engine

## 🚀 Quick Start

```powershell
cd D:\PROJECTS\JARVIX-MULTISTACK

# 1. Build Rust
.\scripts\build.ps1

# 2. Initialize DB
$exe = ".\engine\target\release\jarvix.exe"
& $exe migrate data/jarvix.db

# 3. Run Pipeline
& $exe collect --run demo_001 --input data/seeds.txt
& $exe curate --run demo_001
julia science/score.jl demo_001 data
julia science/actions.jl demo_001 data
npx ts-node app/report.ts demo_001 data

# 4. View Report
# Open: data/reports/demo_001.html
```

## 📁 Project Structure

```
engine/
  └── src/
      ├── main.rs        → CLI (migrate, collect, curate)
      ├── db.rs          → SQLite EventLogger
      ├── collector.rs   → Async HTTP + HTML parser
      └── policy.rs      → Domain/path validation

science/
  ├── score.jl           → Scoring algorithm (ponderado)
  └── actions.jl         → Action recommendations (BUY/MONITOR/SKIP)

app/
  └── report.ts          → HTML report generator

scripts/
  ├── build.ps1          → Cargo build
  └── run_mvp.ps1        → Full orchestrator

data/
  ├── seeds.txt          → Input URLs (5 public domains)
  ├── allowed_domains.txt    → Whitelist (6 domains)
  ├── paywall_keywords.txt   → Paywall detection (14 keywords)
  └── [outputs]/
      ├── raw/           → Downloaded HTML
      ├── clean/         → Valid JSONL records
      ├── invalid/       → Records with errors
      ├── scores/        → Scored JSONL
      ├── actions/       → Action recommendations with confidence
      ├── top/           → Top-10 JSON
      └── reports/       → HTML dashboards
```

## 📊 Pipeline Flow

```
seeds.txt → 
  [collect] → HTML files →
  [curate] → JSONL (clean + invalid) →
  [score.jl] → Scored JSONL →
  [actions.jl] → Action recommendations →
  [report.ts] → HTML dashboard
```

## ✅ Test Results (mvp_test_001)

```
✅ Collect:  4/5 URLs downloaded successfully
   - example.com ✓
   - httpbin.org/html ✓  
   - httpbin.org/json ✓
   - w3schools.com/html ✓
   - wikipedia.org ✗ (HTTP 403 blocked)

✅ Curate:   2 clean records + 2 invalid records

✅ Score:    Mean: 47.4, Max: 58.0, Min: 36.8

✅ Report:   Interactive HTML with top-10 table
             Stats: record count, avg score, buy intent %
```

## 🔧 CLI Commands

| Command | Purpose |
|---------|---------|
| `jarvix migrate <db_path>` | Initialize SQLite database |
| `jarvix collect --run <ID> --input <file>` | Download URLs and apply policy gate |
| `jarvix curate --run <ID>` | Parse HTML, extract signals, separate valid/invalid |

## 📈 Scoring Algorithm

- **40%** Quality Score (100-point scale with deductions)
- **30%** Buy Keywords detected
- **20%** Text length normalized (0-100)
- **-10%** Error count penalty

Output: data/scores/`<run_id>`.jsonl (all), data/top/`<run_id>`.json (top 10)

## 🎯 Action Recommendations Engine (Phase 1)

Transforms numeric scores into actionable business decisions with confidence levels:

| Score Range | Action | Confidence | Reason | Next Step |
|-------------|--------|------------|--------|-----------|
| **> 75** | **BUY** | 95% | Premium opportunity with high quality | Contact provider immediately |
| **50-75** | **MONITOR** | 70% | Medium potential, needs evaluation | Evaluate competence for 30 days |
| **< 50** | **SKIP** | 85% | Low quality or insufficient signals | Discard and focus on higher-value targets |

**Output Format**: Each record enriched with:
- `action`: Recommendation type (BUY/MONITOR/SKIP)
- `confidence`: Confidence level (0.0-1.0)
- `reason`: Human-readable explanation
- `next_step`: Suggested action to take

**Files Generated**:
- `data/actions/<run_id>.jsonl` - All records with action recommendations
- `data/actions/<run_id>_summary.json` - Statistics and aggregations

**Usage**:
```bash
julia science/actions.jl demo_001 data
```

## 🛡️ Policy Gate

**Allowed**: Only whitelisted domains (allowed_domains.txt)
**Blocked Paths**: /login, /auth, /account, /subscribe, /admin, /messages
**Blocked Methods**: Only GET/HEAD allowed
**Blocked HTTP Codes**: 401/403 blocks domain, 429 raises error
**Paywall Detection**: Keyword matching (paywall_keywords.txt)

## 📚 Documentation

For detailed information, see:
- **README.md** - This file (MVP overview)
- **V2_ROADMAP.md** - 🚀 Evolution to "Intelligence Factory" (acciones, auto-discovery, APIs, trends)
- **D:\PROYECTOS.md** - All projects including JARVIX details
- **D:\REGLAS_IMPLEMENTADAS.md** - Implementation patterns
- **D:\SISTEMA.md** - Architecture overview

## 🎯 Implementation Stats

| Component | Lines | Status |
|-----------|-------|--------|
| engine/src/main.rs | 199 | ✅ |
| engine/src/db.rs | 78 | ✅ |
| engine/src/collector.rs | 232 | ✅ |
| engine/src/policy.rs | 175 | ✅ |
| science/score.jl | 130 | ✅ |
| science/actions.jl | 250 | ✅ Phase 1 |
| app/report.ts | 290 | ✅ |
| scripts/run_mvp.ps1 | 190 | ✅ |

**Total**: ~1,650 lines production code

## 🔄 Full Automation

Run the complete pipeline with one command:
```powershell
.\scripts\run_mvp.ps1 -RunId "production_001"
```

---

✅ **MVP COMPLETED** - All components functional, tested end-to-end, ready for deployment
