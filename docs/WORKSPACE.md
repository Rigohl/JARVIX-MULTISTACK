# VS Code Workspace Setup para JARVIX-MULTISTACK

## Configuración Multilenguaje

Este proyecto usa **Rust, Julia, TypeScript y PowerShell**. Las configuraciones están en `.vscode/`:

### settings.json
- Formateadores automáticos por lenguaje
- Rust: rust-analyzer con clippy
- Julia: language-julia formatter
- TypeScript: Prettier
- PowerShell: ms-vscode.PowerShell

### tasks.json
Ejecutar con **Ctrl+Shift+B** (Build) o **Ctrl+Shift+D** (Test):

```bash
# Build release binary
Rust: Build Release

# Run full pipeline
PowerShell: Run MVP

# Scoring
Julia: Score

# Report generation
TypeScript: Generate Report
```

### launch.json
Depuración Rust: **F5** inicia el debugger con `cargo build` automático.

## Para Copilot Coding Agent

Cuando asignes una issue:
1. Etiqueta el issue con `#1` (Phase 1), etc.
2. El agente tendrá acceso al workspace completo
3. Usa tareas predefinidas para validar cambios

**Contexto clave para Copilot**:
- Estructura: `engine/` (Rust) → `science/` (Julia) → `app/` (TypeScript)
- Datos: `data/` (config, scores, reports)
- Orquestación: `scripts/run_mvp.ps1`
- Logs: SQLite en `data/jarvix.db`

## Extensiones Recomendadas

```json
rust-lang.rust-analyzer
julialang.language-julia
esbenp.prettier-vscode
ms-vscode.PowerShell
```

## Próximas Fases (con Copilot)

- Phase 1: Actions engine (Julia) → Assign #1
- Phase 2: Auto-discovery (Rust) → Assign #2
- Phase 4: PDF export (TypeScript) → Assign #4
