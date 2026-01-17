-- JARVIX-MULTISTACK SQLite Schema
-- Base de datos central para el proyecto

-- Tabla de configuración del sistema
CREATE TABLE IF NOT EXISTS config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de experimentos JAX
CREATE TABLE IF NOT EXISTS experiments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    status TEXT CHECK(status IN ('running', 'completed', 'failed')),
    results_path TEXT,
    parameters TEXT -- JSON
);

-- Tabla de resultados de entrenamiento
CREATE TABLE IF NOT EXISTS training_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id INTEGER NOT NULL,
    epoch INTEGER,
    loss REAL,
    accuracy REAL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (experiment_id) REFERENCES experiments(id)
);

-- Tabla de logs del sistema
CREATE TABLE IF NOT EXISTS system_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level TEXT CHECK(level IN ('INFO', 'WARN', 'ERROR', 'DEBUG')),
    module TEXT,
    message TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de dependencias y versiones
CREATE TABLE IF NOT EXISTS versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component TEXT UNIQUE NOT NULL,
    version TEXT NOT NULL,
    installed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_experiments_status ON experiments(status);
CREATE INDEX IF NOT EXISTS idx_training_results_experiment ON training_results(experiment_id);
CREATE INDEX IF NOT EXISTS idx_system_logs_level ON system_logs(level);
CREATE INDEX IF NOT EXISTS idx_system_logs_timestamp ON system_logs(timestamp);

-- Inserts iniciales
INSERT OR IGNORE INTO config (key, value) VALUES 
    ('project_name', 'JARVIX-MULTISTACK'),
    ('environment', 'development'),
    ('version', '1.0.0');

INSERT OR IGNORE INTO versions (component, version) VALUES 
    ('rust', 'latest'),
    ('node', 'latest'),
    ('python', 'latest'),
    ('julia', 'latest'),
    ('sqlite', '3.0'),
    ('jax', 'latest'),
    ('chapel', 'latest');
