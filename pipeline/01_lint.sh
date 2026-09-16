#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 1: Linting y análisis estático de código (Flake8 + Bandit)
#
# Justificación de riesgo:
#   La app maneja autenticación y datos de usuarios. Un error de estilo puede
#   esconder lógica incorrecta, y Bandit detecta patrones inseguros en Python
#   (uso de eval, inyección SQL, contraseñas en código) antes de que lleguen
#   al contenedor.
#
# Umbrales:
#   Flake8  → bloquea si hay CUALQUIER error de sintaxis o estilo crítico.
#   Bandit  → bloquea si encuentra hallazgos de severidad HIGH o CRITICAL.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reportes}"
ETAPA="[ETAPA-1 LINT]"

echo "$ETAPA Iniciando análisis estático..."

# ── Instalar herramientas si no están disponibles ─────────────────────────────
pip3 install --quiet flake8==7.1.0 bandit==1.7.9 || pip install --quiet flake8==7.1.0 bandit==1.7.9

# ── Flake8: estilo y errores de sintaxis ──────────────────────────────────────
echo "$ETAPA Ejecutando Flake8..."
flake8 app/ \
  --max-line-length=120 \
  --exclude=app/templates,app/static \
  --statistics \
  --tee --output-file="${REPORT_DIR}/flake8_report.txt" || {
    echo "$ETAPA ❌ BLOQUEADO — Flake8 encontró errores."
    exit 2
}
echo "$ETAPA ✅ Flake8 sin errores."

# ── Bandit: patrones de seguridad en Python ───────────────────────────────────
echo "$ETAPA Ejecutando Bandit..."
bandit -r app/ \
  --exclude app/templates,app/static \
  -l \
  -f txt \
  -o "${REPORT_DIR}/bandit_report.txt" || true   # Bandit sale con 1 si hay hallazgos

# Contar hallazgos HIGH o CRITICAL
HIGH_COUNT=$(grep -c "Severity: High\|Severity: Critical" "${REPORT_DIR}/bandit_report.txt" 2>/dev/null || echo "0")

echo "$ETAPA Bandit encontró $HIGH_COUNT hallazgo(s) HIGH/CRITICAL."

if [ "${HIGH_COUNT}" -gt 0 ]; then
  echo "$ETAPA ❌ BLOQUEADO — Umbral: 0 hallazgos HIGH/CRITICAL."
  exit 2
fi

echo "$ETAPA ✅ Bandit OK — sin hallazgos HIGH/CRITICAL."
echo "$ETAPA Etapa completada exitosamente."
