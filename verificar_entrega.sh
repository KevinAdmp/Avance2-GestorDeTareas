#!/usr/bin/env bash
# =============================================================================
# verificar_entrega.sh — Gestor de Tareas Colaborativo
# =============================================================================
# Verifica que todos los archivos y requisitos mínimos de la entrega existen.
# NO califica la calidad — eso lo hace el profesor.
# Si algo aparece como FALTA, esa parte no está entregada.
#
# Uso:  ./verificar_entrega.sh
# =============================================================================
set -uo pipefail

# ── Colores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

ok()   { echo -e "  ${GREEN}✅  OK${NC}    $1"; ((PASS++)); }
falta(){ echo -e "  ${RED}❌  FALTA${NC} $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠️   WARN${NC}  $1"; }
titulo(){ echo -e "\n${BOLD}${CYAN}── $1 ──${NC}"; }

check_file() {
  local ruta="$1"
  local desc="${2:-$1}"
  if [ -f "$ruta" ]; then
    ok "$desc"
  else
    falta "$desc  →  $ruta"
  fi
}

check_dir() {
  local ruta="$1"
  local desc="${2:-$1}"
  if [ -d "$ruta" ]; then
    ok "$desc"
  else
    falta "$desc  →  $ruta"
  fi
}

check_no_completar() {
  local ruta="$1"
  if [ -f "$ruta" ]; then
    if grep -q "\[COMPLETAR\]" "$ruta" 2>/dev/null; then
      warn "$ruta  contiene [COMPLETAR] sin rellenar"
      ((FAIL++))
    else
      ok "$ruta  sin marcadores [COMPLETAR]"
    fi
  fi
}

check_no_credentials() {
  local ruta="$1"
  if [ -f "$ruta" ]; then
    # Buscar patrones comunes de credenciales hardcodeadas
    if grep -qE "(AKIA[0-9A-Z]{16}|aws_secret|password\s*=\s*['\"][^'\"]{8,}|SECRET_KEY\s*=\s*['\"][^'\"]{8,})" "$ruta" 2>/dev/null; then
      warn "$ruta  puede contener credenciales hardcodeadas — revisar manualmente"
    fi
  fi
}

# ── Encabezado ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗"
echo -e "║        VERIFICADOR DE ENTREGA — AVANCE 2                     ║"
echo -e "║        Gestor de Tareas Colaborativo                         ║"
echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "  Fecha: $(date '+%Y-%m-%d %H:%M:%S')"

# ── 1. Estructura de carpetas ─────────────────────────────────────────────────
titulo "1. Estructura de carpetas"
check_dir "app"              "Carpeta app/"
check_dir "app/routes"       "Carpeta app/routes/"
check_dir "app/templates"    "Carpeta app/templates/"
check_dir "app/worker"       "Carpeta app/worker/"
check_dir "infra"            "Carpeta infra/"
check_dir "pipeline"         "Carpeta pipeline/"
check_dir "reportes"         "Carpeta reportes/"
check_dir "docs"             "Carpeta docs/"

# ── 2. Código de la aplicación ────────────────────────────────────────────────
titulo "2. Aplicación Flask"
check_file "app/app.py"              "app/app.py — factory Flask"
check_file "app/config.py"           "app/config.py — configuración"
check_file "app/models.py"           "app/models.py — modelos BD"
check_file "app/extensions.py"       "app/extensions.py — extensiones"
check_file "app/queue_client.py"     "app/queue_client.py — publicador RabbitMQ"
check_file "app/s3_client.py"        "app/s3_client.py — cliente S3"
check_file "app/wsgi.py"             "app/wsgi.py — punto de entrada Gunicorn"
check_file "app/requirements.txt"    "app/requirements.txt"
check_file "app/routes/auth.py"      "app/routes/auth.py — autenticación"
check_file "app/routes/tableros.py"  "app/routes/tableros.py"
check_file "app/routes/tarjetas.py"  "app/routes/tarjetas.py"
check_file "app/routes/health.py"    "app/routes/health.py — endpoint /salud"

# ── 3. Worker (pieza técnica distintiva) ──────────────────────────────────────
titulo "3. Worker RabbitMQ (pieza técnica distintiva Tema 5)"
check_file "app/worker/worker.py"          "app/worker/worker.py — consumer RabbitMQ"
check_file "app/worker/requirements.txt"   "app/worker/requirements.txt"

# ── 4. Contenedores ───────────────────────────────────────────────────────────
titulo "4. Contenedores"
check_file "Dockerfile"          "Dockerfile — API endurecido"
check_file "Dockerfile.worker"   "Dockerfile.worker — Worker endurecido"
check_file "docker-compose.yml"  "docker-compose.yml — orquestación"

# Verificar requisitos del Dockerfile
titulo "4a. Verificaciones del Dockerfile"
if [ -f "Dockerfile" ]; then
  grep -q "FROM python:.*-slim" Dockerfile && ok "Imagen base con versión fija (slim)" || falta "Imagen base sin versión fija"
  grep -q "USER " Dockerfile && ok "Usuario sin privilegios definido" || falta "Falta usuario sin privilegios (USER)"
  grep -q "HEALTHCHECK" Dockerfile && ok "HEALTHCHECK definido" || falta "Falta HEALTHCHECK"
  grep -q "SECRET_KEY\|password\|PASSWORD" Dockerfile && warn "Dockerfile puede contener credenciales — revisar" || ok "Sin credenciales aparentes en Dockerfile"
fi

# ── 5. Infraestructura como código ────────────────────────────────────────────
titulo "5. Infraestructura como código"
check_file "infra/main.tf"  "infra/main.tf — Terraform S3 + RDS"

if [ -f "infra/main.tf" ]; then
  grep -q "aws_s3_bucket" infra/main.tf && ok "  Recurso S3 definido" || falta "  Falta recurso aws_s3_bucket en main.tf"
  grep -q "aws_db_instance" infra/main.tf && ok "  Recurso RDS definido" || falta "  Falta recurso aws_db_instance en main.tf"
  grep -q "block_public_acls" infra/main.tf && ok "  S3 public access block configurado" || falta "  Falta bloqueo de acceso público en S3"
  grep -q "storage_encrypted" infra/main.tf && ok "  RDS cifrado configurado" || falta "  Falta storage_encrypted en RDS"
  grep -q "publicly_accessible.*false" infra/main.tf && ok "  RDS sin acceso público" || falta "  Falta publicly_accessible=false en RDS"
fi

# ── 6. Pipeline ───────────────────────────────────────────────────────────────
titulo "6. Pipeline DevSecOps"
check_file "pipeline/pipeline.sh"         "pipeline/pipeline.sh — orquestador principal"
check_file "pipeline/01_lint.sh"          "pipeline/01_lint.sh"
check_file "pipeline/02_secrets_scan.sh"  "pipeline/02_secrets_scan.sh"
check_file "pipeline/03_sca.sh"           "pipeline/03_sca.sh"
check_file "pipeline/04_iac_scan.sh"      "pipeline/04_iac_scan.sh"
check_file "pipeline/05_container_scan.sh" "pipeline/05_container_scan.sh"
check_file "pipeline/06_health_check.sh"  "pipeline/06_health_check.sh"
check_file "pipeline/Jenkinsfile"         "pipeline/Jenkinsfile"

# Verificar que el pipeline tiene veredicto integrado
if [ -f "pipeline/pipeline.sh" ]; then
  grep -q "VEREDICTO\|BLOQUEADO\|PERMITIDO" pipeline/pipeline.sh && \
    ok "  Veredicto final integrado presente" || \
    falta "  Falta veredicto final integrado en pipeline.sh"
fi

# ── 7. Reportes ───────────────────────────────────────────────────────────────
titulo "7. Reportes de corridas"
check_file "reportes/corrida_roja.txt"     "reportes/corrida_roja.txt — pipeline bloqueando"
check_file "reportes/corrida_verde.txt"    "reportes/corrida_verde.txt — pipeline permitiendo"
check_file "reportes/sbom_cyclonedx.json"  "reportes/sbom_cyclonedx.json — SBOM CycloneDX"

# Verificar que la corrida roja realmente muestra un bloqueo
if [ -f "reportes/corrida_roja.txt" ]; then
  grep -qi "BLOQUEADO\|FAIL\|ERROR\|blocked" reportes/corrida_roja.txt && \
    ok "  corrida_roja.txt contiene evidencia de bloqueo" || \
    warn "  corrida_roja.txt no muestra evidencia clara de bloqueo"
fi

# Verificar que la corrida verde muestra PERMITIDO
if [ -f "reportes/corrida_verde.txt" ]; then
  grep -qi "PERMITIDO\|PASS\|verde\|allowed" reportes/corrida_verde.txt && \
    ok "  corrida_verde.txt contiene evidencia de paso" || \
    warn "  corrida_verde.txt no muestra evidencia clara de paso"
fi

# Verificar SBOM es JSON válido
if [ -f "reportes/sbom_cyclonedx.json" ]; then
  python3 -c "import json; json.load(open('reportes/sbom_cyclonedx.json'))" 2>/dev/null && \
    ok "  sbom_cyclonedx.json es JSON válido" || \
    falta "  sbom_cyclonedx.json no es JSON válido"
  grep -q "CycloneDX" reportes/sbom_cyclonedx.json && \
    ok "  sbom_cyclonedx.json tiene formato CycloneDX" || \
    falta "  sbom_cyclonedx.json no tiene formato CycloneDX"
fi

# ── 8. Documentación ──────────────────────────────────────────────────────────
titulo "8. Documentación"
check_file "docs/README.md"                      "docs/README.md"
check_file "docs/ADR-001-decisiones-tecnicas.md" "docs/ADR-001-decisiones-tecnicas.md"
check_file "docs/tabla_decisiones_pipeline.md"   "docs/tabla_decisiones_pipeline.md"
check_file "docs/declaracion_uso_ia.md"          "docs/declaracion_uso_ia.md"

# Verificar [COMPLETAR] en documentos
check_no_completar "docs/README.md"
check_no_completar "docs/ADR-001-decisiones-tecnicas.md"
check_no_completar "docs/tabla_decisiones_pipeline.md"
check_no_completar "docs/declaracion_uso_ia.md"

# El diagrama de arquitectura es generado manualmente — solo avisar
if [ -f "docs/diagrama_arquitectura.png" ]; then
  ok "docs/diagrama_arquitectura.png — diagrama presente"
else
  warn "docs/diagrama_arquitectura.png — PENDIENTE (generar manualmente con draw.io o similar)"
fi

# Video
if [ -f "docs/enlace_video.txt" ]; then
  grep -q "\[COMPLETAR\]" docs/enlace_video.txt && \
    warn "docs/enlace_video.txt — enlace del video pendiente de completar" || \
    ok "docs/enlace_video.txt — enlace presente"
else
  falta "docs/enlace_video.txt o video/ — falta el video o su enlace"
fi

# ── 9. Seguridad básica ───────────────────────────────────────────────────────
titulo "9. Seguridad básica"

# .env no debe estar en el repositorio
if [ -f ".env" ]; then
  warn ".env existe — asegúrate de que NO esté trackeado por git"
  git ls-files --error-unmatch .env 2>/dev/null && \
    falta ".env está trackeado por git — REMOVER INMEDIATAMENTE" || \
    ok ".env no está trackeado por git"
else
  ok ".env no existe en el directorio (correcto para el repo)"
fi

check_file ".env.example"  ".env.example — plantilla de variables"
check_file ".gitignore"    ".gitignore"

if [ -f ".gitignore" ]; then
  grep -q "\.env" .gitignore && ok "  .env está en .gitignore" || falta "  .env NO está en .gitignore"
fi

# Verificar que config.py no tiene credenciales hardcodeadas
check_no_credentials "app/config.py"
check_no_credentials "infra/main.tf"

# ── Resumen final ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  RESULTADO FINAL"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}✅  OK:   $PASS${NC}"
echo -e "  ${RED}❌  FALTA: $FAIL${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${BOLD}${GREEN}  ╔═══════════════════════════════════════════╗"
  echo -e "  ║  Entrega completa — lista para subir 🎉   ║"
  echo -e "  ╚═══════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${YELLOW}Pendientes manuales (no verificables por script):${NC}"
  echo -e "  • Graba el video de 3-5 min y agrega el enlace en docs/enlace_video.txt"
  echo -e "  • Crea docs/diagrama_arquitectura.png con draw.io o similar"
  echo -e "  • Corre el pipeline real para generar las corridas definitivas"
  echo -e "  • Completa la Plantilla_Evidencias_Avance2 en la plataforma"
  exit 0
else
  echo -e "${BOLD}${RED}  ╔═══════════════════════════════════════════╗"
  echo -e "  ║  Hay $FAIL elemento(s) faltante(s).         ║"
  echo -e "  ║  Revisa los ❌ arriba antes de entregar.   ║"
  echo -e "  ╚═══════════════════════════════════════════╝${NC}"
  exit 1
fi
