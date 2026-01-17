# JARVIX-MULTISTACK Setup.ps1
# Setup completo para Windows + VS Code
# Stack: Rust + Chapel + Julia + Node.js + Python (JAX) + SQLite

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# ============= UTILIDADES =============
function Write-Title { param([string]$Text)
    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

function Write-Step { param([string]$Text, [int]$Step, [int]$Total)
    Write-Host "`n[$Step/$Total] $Text" -ForegroundColor Blue
}

function Write-Success { param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Warn { param([string]$Text)
    Write-Host "  [!] $Text" -ForegroundColor Yellow
}

function Check-Cmd { param([string]$Cmd, [string]$Name)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        $Ver = & $Cmd --version 2>&1 | Select-Object -First 1
        Write-Success "$Name`: $Ver"
        return $true
    } else {
        Write-Warn "$Name`: NO ENCONTRADO"
        return $false
    }
}

# ============= INICIO =============
Write-Title "JARVIX-MULTISTACK Setup (Windows)"

$ProjectDir = Get-Location
$AppDir = "$ProjectDir\app"
$EngineDir = "$ProjectDir\engine"
$ScienceDir = "$ProjectDir\science"
$TrainDir = "$ProjectDir\train"
$DataDir = "$ProjectDir\data"
$ScriptsDir = "$ProjectDir\scripts"
$DocsDir = "$ProjectDir\docs"

Write-Host "`nProyecto: $ProjectDir`n" -ForegroundColor Cyan

# PASO 1: CARPETAS
Write-Step "Creando carpetas" 1 8

$Folders = @($AppDir, $EngineDir, $ScienceDir, $TrainDir, $DataDir, $ScriptsDir, $DocsDir)
foreach ($F in $Folders) {
    if (-not (Test-Path $F)) {
        New-Item -ItemType Directory -Path $F -Force | Out-Null
    }
    Write-Success "$(Split-Path $F -Leaf)/"
}

# PASO 2: GIT
Write-Step "Verificando Git" 2 8
Check-Cmd "git" "Git" | Out-Null

# PASO 3: NODE.JS
Write-Step "Verificando Node.js" 3 8
if (Check-Cmd "node" "Node.js") {
    if (-not (Test-Path "$AppDir\package.json")) {
        Write-Host "  Inicializando npm..." -ForegroundColor Yellow
        Push-Location $AppDir
        npm init -y 2>&1 | Out-Null
        npm install --save-dev ts-node typescript @types/node 2>&1 | Out-Null
        Pop-Location
        Write-Success "package.json creado"
    }
}

# PASO 4: PYTHON
Write-Step "Verificando Python 3" 4 8
if (Check-Cmd "python" "Python") {
    if (-not (Test-Path "$TrainDir\.venv")) {
        Write-Host "  Creando virtualenv..." -ForegroundColor Yellow
        python -m venv "$TrainDir\.venv"
        Write-Success "Virtualenv creado"
    }
    
    Write-Host "  Activando venv..." -ForegroundColor Yellow
    & "$TrainDir\.venv\Scripts\Activate.ps1"
    
    Write-Host "  Instalando dependencias..." -ForegroundColor Yellow
    python -m pip install --upgrade pip -q 2>&1 | Out-Null
    pip install numpy pandas matplotlib scipy scikit-learn jupyter ipython -q 2>&1 | Out-Null
    
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        Write-Success "GPU detectada"
        pip install "jax[cuda11_cudnn82]" -q 2>&1 | Out-Null
    } else {
        pip install jax -q 2>&1 | Out-Null
    }
    
    Write-Success "Python + JAX instalado"
    pip freeze > "$TrainDir\requirements.txt"
    
    deactivate 2>&1 | Out-Null
} else {
    Write-Host "FATAL: Python requerido" -ForegroundColor Red
    exit 1
}

# PASO 5: RUST
Write-Step "Verificando Rust" 5 8
if (Check-Cmd "rustc" "Rust") {
    if (-not (Test-Path "$EngineDir\Cargo.toml")) {
        Write-Host "  Inicializando Cargo..." -ForegroundColor Yellow
        Push-Location $EngineDir
        cargo init --name jarvix-engine 2>&1 | Out-Null
        Pop-Location
        Write-Success "Cargo.toml creado"
    }
}

# PASO 6: JULIA
Write-Step "Verificando Julia (opcional)" 6 8
Check-Cmd "julia" "Julia" | Out-Null

# PASO 7: SQLITE3
Write-Step "Verificando SQLite3" 7 8
if (Check-Cmd "sqlite3" "SQLite3") {
    if (-not (Test-Path "$DataDir\jarvix.db")) {
        Write-Host "  Creando BD..." -ForegroundColor Yellow
        if (Test-Path "$DataDir\schema.sql") {
            sqlite3 "$DataDir\jarvix.db" (Get-Content "$DataDir\schema.sql")
            Write-Success "BD creada"
        }
    }
}

# PASO 8: CONFIG
Write-Step "Creando archivos" 8 8
if (-not (Test-Path "$ProjectDir\.env")) {
    if (Test-Path "$ProjectDir\.env.example") {
        Copy-Item "$ProjectDir\.env.example" "$ProjectDir\.env" -ErrorAction SilentlyContinue
        Write-Success ".env creado"
    }
}

$ActScript = @"
Write-Host "Activando JARVIX..." -ForegroundColor Green
& "$TrainDir\.venv\Scripts\Activate.ps1"
Write-Host "OK - Listo para usar`n" -ForegroundColor Green
"@
$ActScript | Out-File "$ScriptsDir\activate.ps1" -Encoding UTF8

Write-Success "activate.ps1 creado"

# RESUMEN
Write-Title "Setup Completado"
Write-Host @"
Proximos pasos:
  1. & "$ScriptsDir\activate.ps1"        # Activar entorno
  2. & "$ScriptsDir\verify.ps1"          # Verificar todo
  3. python train\test_gpu.py            # Test JAX
  4. cd engine && cargo build            # Build Rust
"@ -ForegroundColor Cyan

Write-Host ""
