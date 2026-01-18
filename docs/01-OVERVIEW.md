# JARVIX v2.0 - Overview & Architecture

## Project Vision

Transform OSINT & competitor intelligence from **manual 5-URL analysis** to **automated 10K+ URL processing** with ML-driven scoring and recommendations.

**Timeline**: MVP (v1.0) → Production Intelligence Factory (v2.0) in 6 phases

## Stack

| Layer | Technology | Version | Phases |
|-------|-----------|---------|--------|
| **Backend** | Rust | 1.92+ | 2, 5, 6 |
| **Analytics** | Julia | 1.12+ | 1, 3, 6 |
| **Frontend** | TypeScript | 5.9+ | 3, 4 |
| **Database** | SQLite | 3.47+ | All |
| **Async** | Tokio | 1.0+ | 2, 5, 6 |
| **Parallel** | Distributed.jl | Latest | 6 |

## System Architecture

```
INPUT (Discovery/Seeds)
    ↓
[RUST] Collect (100 parallel workers)
    ↓
[RUST] Curate (policy enforcement)
    ↓
[JULIA] Score (ponderado algorithm)
    ↓
[JULIA] Phase 1: Actions (BUY/MONITOR/SKIP)
    ↓
[JULIA] Phase 3: Trends (WoW analysis)
    ↓
[RUST] Phase 5: Enrichment (Multi-API)
    ↓
[TYPESCRIPT] Phase 4: PDF Export
    ↓
[JULIA] Phase 6: Parallel scoring + Parquet storage
    ↓
OUTPUT (Reports, Data, Actions)
```

## Key Components

### Engine (Rust)
- `main.rs` - CLI interface
- `parallel.rs` - 100 concurrent workers (Phase 6)
- `enrichment.rs` - Multi-API enrichment (Phase 5)
- `discovery.rs` - Auto competitor discovery (Phase 2)
- `storage.rs` - Parquet columnar output
- `policy.rs` - Domain validation & paywall detection

### Science (Julia)
- `score.jl` - Original v1.0 ponderado algorithm
- `actions.jl` - BUY/MONITOR/SKIP recommendations (Phase 1)
- `trends.jl` - Week-over-week trend detection (Phase 3)
- `parallel_score.jl` - Distributed.jl MPI scoring (Phase 6)

### App (TypeScript)
- `report.ts` - HTML dashboard generator
- `pdf.ts` - PDFKit export (Phase 4)
- `trend_report.ts` - Trend visualization (Phase 3)

### Data
- `seeds.txt` - Input URLs
- `allowed_domains.txt` - Whitelist
- `api_config.toml` - Phase 5 API keys
- `schema.sql` - SQLite schema with enrichment_cache, opportunity_history

## Development Stats

- **Total LOC Generated**: 12,446 (GitHub Copilot)
- **Phases Completed**: 6/6 ✅
- **Tests Passed**: 6/6 ✅
- **Binary Size**: 11.9 MB (release-optimized)
- **GitHub Commits**: 40+
- **Release**: v2.0.0 (18 Jan 2026)

## Performance Targets (Phase 6)

| Metric | v1.0 | v2.0 | Target |
|--------|------|------|--------|
| URLs/run | 5 | 10,000+ | ✅ |
| Time/URL | 6s | 30ms | ✅ |
| Total time | 30s | 5 min | ✅ |
| Workers | 1 | 100 | ✅ |
| Throughput | 0.16/s | 37/s | ✅ |

## Repository Structure

```
JARVIX-MULTISTACK/
├── engine/              # Rust async core
├── science/             # Julia analytics
├── app/                 # TypeScript frontend
├── data/                # Config & schemas
├── scripts/             # Orchestration
├── docs/                # This documentation
├── jarvix-v2.0.0.exe    # Production binary
└── .vscode/             # Editor config
```

## Quick Start

```bash
# Build from source
cd engine && cargo build --release

# Or use pre-built binary
./jarvix-v2.0.0.exe collect --help

# Run full pipeline
./scripts/run_mvp_with_enrichment.ps1
```

## Next Steps

- [Phases Documentation](02-PHASES.md) - All 6 phases details
- [Architecture Details](03-ARCHITECTURE.md) - System design
- [Capabilities Matrix](04-CAPABILITIES.md) - Expected outputs
- [Scalability Guide](05-SCALABILITY.md) - Performance tuning
- [Testing & Validation](06-TESTING.md) - QA procedures
