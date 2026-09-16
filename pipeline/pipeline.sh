#!/usr/bin/env bash
# =============================================================================
# PIPELINE PRINCIPAL — Gestor de Tareas Colaborativo
# =============================================================================
# Orquesta las 6 etapas de seguridad y produce UN ÚNICO VEREDICTO FINAL.
# El pipeline bloquea en la primera etapa que falle; si todas pasan, permite.
#
# Uso:
#   ./pipeline/pipeline.sh              # corre todas las etapas
#   ./pipeline/pipeline.sh --dry-run    # muestra el plan sin ejecutar
#
# Etapas:
#   1. Lint + análisis estático (Flake8 + Bandit)
#   2. Detección de secretos    (detect-secrets)
#   3. SCA + SBOM               (Safety + CycloneDX)
#   4. Escaneo IaC              (Checkov)
#   5. Escaneo de imagen Docker (Trivy)
#   6. Health check del servicio
# =============================================================================
set -uo pipefail

# ── Directorio raíz del proyecto ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

export REPORT_DIR="${ROOT_DIR}/reportes"
mkdir -p "$REPORT_DIR"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── Colores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Estado global ─────────────────────────────────────────────────────────────
PIPELINE_STATUS=0
declare -A ETAPA_RESULTADO

ETAPAS=(
  "01_lint.sh:Lint y análisis estático (Flake8+Bandit)"
  "02_secrets_scan.sh:Detección de secretos (detect-secrets)"
  "03_sca.sh:SCA y SBOM (Safety+CycloneDX)"
  "04_iac_scan.sh:Escaneo IaC (Checkov)"
  "05_container_scan.sh:Escaneo imagen Docker (Trivy)"
  "06_health_check.sh:Health check /salud"
)

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     PIPELINE DEVSECOPS — GESTOR DE TAREAS COLABORATIVO      ║"
echo "║     $(date '+%Y-%m-%d %H:%M:%S')                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if $DRY_RUN; then
  echo -e "${YELLOW}[DRY-RUN] Modo simulación — no se ejecutan las etapas.${NC}"
  echo ""
  for entry in "${ETAPAS[@]}"; do
    nombre="${entry%%:*}"
    descripcion="${entry#*:}"
    echo -e "  → ${BOLD}$nombre${NC}  $descripcion"
  done
  echo ""
  echo -e "${YELLOW}Fin del dry-run.${NC}"
  exit 0
fi

# ── Ejecutar etapas secuencialmente ──────────────────────────────────────────
for entry in "${ETAPAS[@]}"; do
  script="${entry%%:*}"
  descripcion="${entry#*:}"

  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}▶  $descripcion${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  INICIO=$(date +%s)

  if bash "$SCRIPT_DIR/$script"; then
    FIN=$(date +%s)
    DURACION=$((FIN - INICIO))
    ETAPA_RESULTADO["$script"]="PASS (${DURACION}s)"
    echo -e "${GREEN}✅  PASS — $descripcion (${DURACION}s)${NC}"
  else
    FIN=$(date +%s)
    DURACION=$((FIN - INICIO))
    ETAPA_RESULTADO["$script"]="FAIL (${DURACION}s)"
    PIPELINE_STATUS=1
    echo ""
    echo -e "${RED}❌  FAIL — $descripcion (${DURACION}s)${NC}"
    echo -e "${RED}    Pipeline bloqueado en esta etapa.${NC}"
    break   # detener al primer fallo — fail-fast
  fi
done

# ── Tabla de resumen ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  RESUMEN DE ETAPAS"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
for entry in "${ETAPAS[@]}"; do
  script="${entry%%:*}"
  descripcion="${entry#*:}"
  resultado="${ETAPA_RESULTADO[$script]:-SKIPPED}"
  if [[ "$resultado" == PASS* ]]; then
    echo -e "  ${GREEN}✅ PASS${NC}  $descripcion  ${resultado}"
  elif [[ "$resultado" == FAIL* ]]; then
    echo -e "  ${RED}❌ FAIL${NC}  $descripcion  ${resultado}"
  else
    echo -e "  ${YELLOW}⏭  SKIP${NC}  $descripcion"
  fi
done

# ── VEREDICTO FINAL INTEGRADO ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  VEREDICTO FINAL"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$PIPELINE_STATUS" -eq 0 ]; then
  echo -e "${BOLD}${GREEN}"
  echo "  ╔════════════════════════════════════════╗"
  echo "  ║   ✅  PERMITIDO — Pipeline en verde    ║"
  echo "  ║   Todas las etapas pasaron.            ║"
  echo "  ╚════════════════════════════════════════╝"
  echo -e "${NC}"
  # Guardar corrida verde
  echo "VEREDICTO: PERMITIDO — $(date)" >> "$REPORT_DIR/corrida_verde.txt"
  exit 0
else
  echo -e "${BOLD}${RED}"
  echo "  ╔════════════════════════════════════════╗"
  echo "  ║   ❌  BLOQUEADO — Pipeline en rojo     ║"
  echo "  ║   Al menos una etapa falló.            ║"
  echo "  ╚════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}  Revisa los reportes en: $REPORT_DIR/${NC}"
  # Guardar corrida roja
  echo "VEREDICTO: BLOQUEADO — $(date)" >> "$REPORT_DIR/corrida_roja.txt"
  exit 1
fi
