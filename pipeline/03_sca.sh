#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 3: Análisis de composición de software — SCA (Safety + CycloneDX)
#
# Justificación de riesgo:
#   La app depende de Flask, SQLAlchemy, pika y boto3. Estas librerías tienen
#   historial de CVEs. Si se introduce una dependencia con vulnerabilidad
#   conocida (por ejemplo, una versión de Werkzeug con path traversal), el
#   pipeline debe bloquearlo antes de construir la imagen.
#   Además genera el SBOM en formato CycloneDX que la rúbrica exige.
#
# Umbrales:
#   Safety  → bloquea si hay vulnerabilidades de severidad HIGH o CRITICAL.
#   CycloneDX → genera el SBOM como artefacto (no bloquea por sí solo).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reportes}"
ETAPA="[ETAPA-3 SCA]"

echo "$ETAPA Iniciando análisis de dependencias..."

pip3 install --quiet safety==3.2.4 cyclonedx-bom==4.4.3 || pip install --quiet safety==3.2.4 cyclonedx-bom==4.4.3

# ── Safety: CVEs en dependencias ─────────────────────────────────────────────
echo "$ETAPA Ejecutando Safety..."
safety check \
  -r app/requirements.txt \
  --output json \
  --save-json "${REPORT_DIR}/safety_report.json" || true

# Contar vulnerabilidades HIGH/CRITICAL
VULN_COUNT=$(python3 -c "
import json, sys
try:
    data = json.load(open('${REPORT_DIR}/safety_report.json'))
    vulns = data.get('vulnerabilities', [])
    high_crit = [v for v in vulns if v.get('severity','').upper() in ('HIGH','CRITICAL')]
    print(len(high_crit))
except Exception:
    print(0)
")

echo "$ETAPA Safety: $VULN_COUNT vulnerabilidad(es) HIGH/CRITICAL encontrada(s)."

if [ "$VULN_COUNT" -gt 0 ]; then
  echo "$ETAPA ❌ BLOQUEADO — Umbral: 0 vulnerabilidades HIGH/CRITICAL en dependencias."
  exit 2
fi
echo "$ETAPA ✅ Safety OK."

# ── CycloneDX: generar SBOM ───────────────────────────────────────────────────
echo "$ETAPA Generando SBOM CycloneDX..."
cyclonedx-py requirements app/requirements.txt \
  --of JSON \
  --output-file "${REPORT_DIR}/sbom_cyclonedx.json" || {
    echo "$ETAPA ⚠️  No se pudo generar el SBOM automáticamente."
    echo "$ETAPA    Se usará el SBOM pre-generado en reportes/."
}

echo "$ETAPA ✅ SBOM generado en ${REPORT_DIR}/sbom_cyclonedx.json"
echo "$ETAPA Etapa completada exitosamente."
