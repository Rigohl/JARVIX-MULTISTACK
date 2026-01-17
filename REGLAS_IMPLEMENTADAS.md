# ✅ REGLAS GLOBALES ANTIGRAVITY - IMPLEMENTADAS

## 📚 Basado en Documentación Oficial

He estudiado a fondo la documentación oficial de Antigravity y creado reglas globales sencillas y efectivas.

---

## 🎯 Características de las Reglas Implementadas

### 1. **Ubicación Correcta**
```
D:\.gemini\GEMINI.md  (Windows)
~/.gemini/GEMINI.md   (Linux/Mac)
```

### 2. **Límite de Caracteres**
- ✅ **12,000 caracteres** (límite oficial de Antigravity)
- ✅ Archivo actual: ~11,900 caracteres

### 3. **Formato**
- ✅ Markdown (.md)
- ✅ Texto plano con ejemplos de código
- ✅ Sin YAML frontmatter (no es necesario para reglas globales)

---

## 📋 25 Reglas Implementadas

### ⚡ Modo YOLO (Regla #1)
- Auto-ejecución sin confirmación
- `SafeToAutoRun: true` siempre
- Sin excepciones

### 🔒 Seguridad (Reglas #2-5)
- No hardcoded secrets
- Validación de inputs
- HTTPS obligatorio
- No loguear datos sensibles

### 💎 SOLID (Reglas #6-8)
- Single Responsibility
- DRY (Don't Repeat Yourself)
- Nombres descriptivos

### 📝 Documentación (Reglas #9-10)
- Docstrings obligatorios
- Comentarios útiles

### 🧪 Testing (Reglas #11-12)
- Cobertura mínima 80%
- Tests antes de commit

### 🔄 Git (Regla #13)
- Conventional Commits

### 🎨 Estilo (Reglas #14-15)
- Tipado fuerte
- Manejo robusto de errores

### 🚀 Rendimiento (Reglas #16-17)
- Complejidad algorítmica
- Lazy evaluation

### 📦 Dependencias (Reglas #18-19)
- Security audit
- Versiones específicas

### 🌍 I18n (Regla #20)
- Strings externalizados

### 📊 Logging (Regla #21)
- Logging estructurado

### 🎯 Modularidad (Reglas #22-23)
- Código modular
- Dependency injection

### 🔧 Herramientas (Reglas #24-25)
- Linters y formatters
- Pre-commit hooks

---

## 🔍 Modos de Activación

Según la documentación oficial, las reglas pueden activarse de 4 formas:

### 1. **Always On** (Nuestras reglas)
- ✅ Se aplican automáticamente a TODOS los proyectos
- ✅ No requieren mención explícita
- ✅ Inyectadas en el system prompt

### 2. **Manual**
- Se activan con `@nombre-regla`
- Útil para reglas opcionales

### 3. **Model Decision**
- El modelo decide cuándo aplicarlas
- Basado en descripción en lenguaje natural

### 4. **Glob Pattern**
- Se activan para archivos específicos
- Ejemplo: `*.ts`, `src/**/*.py`

**Nuestras reglas usan "Always On"** porque son fundamentales.

---

## 📊 Comparación: Global vs Workspace

| Aspecto | Reglas Globales | Reglas Workspace |
|---------|----------------|------------------|
| **Ubicación** | `~/.gemini/GEMINI.md` | `.agent/rules/*.md` |
| **Alcance** | Todos los proyectos | Solo proyecto actual |
| **Activación** | Siempre | Configurable |
| **Límite** | 12,000 caracteres | 12,000 por archivo |
| **Propósito** | Principios universales | Convenciones específicas |

---

## 🎯 Ejemplos de Uso

### Regla Global (Ya implementada)
```markdown
# GEMINI.md

## Regla #1: Modo YOLO
Ejecutar TODOS los comandos automáticamente.
SafeToAutoRun: true
```

### Regla Workspace (Para proyecto específico)
```markdown
---
trigger: glob
globs: *.ts, *.tsx
---

# TypeScript Strict Mode

Siempre usar strict mode en TypeScript.
No usar `any` type.
```

---

## ✅ Ventajas de Nuestras Reglas

### 1. **Sencillas**
- Fáciles de entender
- Ejemplos claros
- Sin complejidad innecesaria

### 2. **Efectivas**
- Cubren aspectos fundamentales
- Basadas en best practices
- Aplicables a cualquier proyecto

### 3. **Completas**
- 25 reglas esenciales
- Seguridad, calidad, rendimiento
- Testing y documentación

### 4. **Oficiales**
- Basadas en documentación de Antigravity
- Formato correcto
- Límite de caracteres respetado

---

## 🔧 Cómo Verificar que Funcionan

### 1. Abrir Antigravity
```bash
# Las reglas se cargan automáticamente
```

### 2. Preguntar al Agente
```
"¿Qué reglas globales tienes configuradas?"
```

### 3. Probar una Regla
```
"Crea una función que se conecte a una API"
# El agente debería usar HTTPS automáticamente (Regla #4)
```

### 4. Verificar Modo YOLO
```
"Ejecuta npm install"
# Debería ejecutarse automáticamente sin pedir confirmación (Regla #1)
```

---

## 📚 Recursos Consultados

### Documentación Oficial
- ✅ [antigravity.google](https://antigravity.google)
- ✅ Customizations panel
- ✅ Rules activation methods
- ✅ Character limits
- ✅ Best practices

### Ejemplos Reales
- ✅ Proyectos open-source usando Antigravity
- ✅ Patrones comunes de reglas
- ✅ Casos de uso reales

---

## 🚀 Próximos Pasos

### 1. Reglas de Workspace
Crear reglas específicas para Nuclear Crawler:
```bash
# Ejemplo
.agent/rules/chapel-style.md  # Reglas para Chapel
.agent/rules/rust-clippy.md   # Reglas para Rust
```

### 2. Skills
Crear skills para tareas repetitivas:
```bash
.agent/skills/chapel-formatter/
.agent/skills/ffi-generator/
```

### 3. Workflows
Crear workflows para procesos complejos:
```bash
.agent/workflows/build-all.md
.agent/workflows/test-ffi.md
```

---

## 📊 Estadísticas

| Métrica | Valor |
|---------|-------|
| **Reglas Totales** | 25 |
| **Caracteres** | ~11,900 / 12,000 |
| **Categorías** | 10 (Seguridad, SOLID, Testing, etc.) |
| **Ejemplos de Código** | 40+ |
| **Lenguajes Cubiertos** | Python, TypeScript, Rust, JavaScript |

---

## 🎓 Lecciones Aprendidas

### 1. **Simplicidad es Clave**
- Reglas claras y concisas
- Ejemplos prácticos
- Sin ambigüedades

### 2. **Always On por Defecto**
- Reglas fundamentales siempre activas
- No requieren mención explícita
- Consistencia garantizada

### 3. **Ejemplos son Esenciales**
- Mostrar ❌ MAL y ✅ BIEN
- Código real, no teoría
- Múltiples lenguajes

### 4. **Prioridades Claras**
- Seguridad primero
- Modo YOLO segundo
- Calidad tercero

---

**Implementación Completada**: ✅  
**Basado en**: Documentación Oficial de Antigravity  
**Fecha**: 16 de Enero de 2026  
**Versión**: 2026.1.0  
**Modo**: YOLO Enabled

🎯 **Reglas globales sencillas y efectivas listas para usar!**
