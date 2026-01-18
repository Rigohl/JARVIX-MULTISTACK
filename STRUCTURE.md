# JARVIX v2.0 - Project Structure

## Directory Organization

```
JARVIX-MULTISTACK/
├── engine/                    # Rust core (Tokio async, 100 workers)
│   ├── src/
│   │   ├── main.rs           → CLI interface
│   │   ├── lib.rs            → Module exports
│   │   ├── parallel.rs       → Phase 6: 100 concurrent workers
│   │   ├── enrichment.rs     → Phase 5: Multi-API enrichment
│   │   └── storage.rs        → Parquet columnar storage
│   └── Cargo.toml            → Rust dependencies (url, toml, async-trait, sha2)
│
├── science/                   # Julia analytics (v1.0 + Phases 1,3,6)
│   ├── score.jl              → Original scoring algorithm
│   ├── actions.jl            → Phase 1: BUY/MONITOR/SKIP recommendations
│   ├── trends.jl             → Phase 3: Week-over-week trend detection
│   ├── weekly_trends.jl      → Phase 3: Cron-based weekly runner
│   ├── parallel_score.jl     → Phase 6: Distributed.jl MPI scoring
│   └── Project.toml          → Julia dependencies
│
├── app/                       # TypeScript frontend (Phases 3,4)
│   ├── report.ts             → HTML dashboard generator
│   ├── pdf.ts                → Phase 4: PDFKit + Chart.js export
│   ├── trend_report.ts       → Phase 3: Trend HTML visualization
│   └── package.json          → Node.js dependencies
│
├── data/                      # Configuration & schemas
│   ├── seeds.txt             → Input URLs
│   ├── allowed_domains.txt   → Whitelist
│   ├── paywall_keywords.txt  → Paywall detector
│   ├── api_config.toml       → Phase 5: API keys configuration
│   ├── schema.sql            → SQLite schema
│   ├── jarvix.db             → SQLite database (auto-created)
│   └── actions/              → Generated action files (JSONL)
│
├── scripts/                   # Orchestration & utilities
│   ├── run_mvp.ps1           → v1.0 pipeline runner
│   ├── run_mvp_with_enrichment.ps1 → v2.0 with Phase 5 enrichment
│   ├── benchmark.sh          → Phase 6: Performance benchmarking
│   └── ...
│
├── docs/                      # Consolidated documentation
│   ├── EXPECTED_RESULTS.md    → v2.0 capabilities matrix & expected outputs
│   ├── V2_ROADMAP.md          → Development roadmap (6 phases)
│   ├── DISCOVERY.md           → Phase 2: Auto-discovery documentation
│   ├── PHASE2_COMPLETE.md     → Phase 2: Discovery implementation details
│   ├── PHASE3_SUMMARY.md      → Phase 3: Trend analysis guide
│   ├── PHASE3_TRENDS.md       → Phase 3: Technical trends documentation
│   ├── PHASE6_COMPLETE.md     → Phase 6: Scalability implementation
│   ├── PHASE6_SCALABILITY.md  → Phase 6: Performance guide
│   ├── IMPLEMENTATION_SUMMARY.md → Overall implementation notes
│   ├── INTEGRATION_PLAN.md    → Phase integration strategy
│   ├── MVP_COMPLETADO.md      → MVP completion checklist
│   ├── REGLAS_IMPLEMENTADAS.md → Implemented rules
│   ├── SISTEMA.md             → System architecture
│   ├── VALIDATION.md          → Testing & validation plan
│   ├── WORKSPACE.md           → Workspace notes
│   └── PROYECTOS.md           → Project planning
│
├── .vscode/                   # Editor configuration
│   ├── settings.json         → Formatting rules, linting
│   ├── launch.json           → Debug configuration
│   └── tasks.json            → Build & test tasks
│
├── .git/                      # Git repository
├── .gitignore                 # Ignore rules (Rust target/, node_modules/, etc.)
├── .env                       # Environment variables (gitignored)
├── .env.example               → Example environment config
│
├── jarvix-v2.0.0.exe         → Production binary (11.9 MB, release-optimized)
├── README.md                 → Main project documentation
├── .copilot-instructions.md  → GitHub Copilot context (150 LOC)
├── Cargo.lock                → Rust lock file (for reproducibility)
└── STRUCTURE.md              → This file
```

## Key Changes in v2.0

✅ **Removed**:
- `Dockerfile` - No Docker (per requirements)
- `docker-compose.yml` - No Docker orchestration
- `node_modules/` - TypeScript deps (install on demand)

✅ **Consolidated**:
- All documentation moved to `docs/` (16 files)
- Cargo.toml updated with all dependencies: `url`, `toml`, `async-trait`, `sha2`
- .gitignore expanded for all build artifacts

✅ **Added**:
- `jarvix-v2.0.0.exe` - Production binary
- `STRUCTURE.md` - This documentation

## Build & Run

```bash
# Build Rust engine (11.9 MB release binary)
cd engine
cargo build --release

# Run pre-built binary
../jarvix-v2.0.0.exe collect --help

# Run full v2.0 pipeline with all 6 phases
../scripts/run_mvp_with_enrichment.ps1
```

## Stack Summary

| Component | Version | Phase | Status |
|-----------|---------|-------|--------|
| Rust | 1.92+ | 2,5,6 | ✅ Complete |
| Julia | 1.12+ | 1,3,6 | ✅ Complete |
| TypeScript | 5.9+ | 3,4 | ✅ Complete |
| SQLite | 3.47+ | All | ✅ Complete |

## Total Codebase

- **LOC Generated**: 12,446 (all 6 phases by Copilot)
- **Commits**: 40+ (including merges)
- **Tests**: ✅ All passed (6/6 phases)
- **Release**: v2.0.0 tagged & pushed
