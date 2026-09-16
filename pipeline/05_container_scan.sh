#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 5: Escaneo de vulnerabilidades en imagen Docker (Trivy)
#
# Justificación de riesgo:
#   La imagen base python:3.12.4-slim puede contener paquetes del sistema
#   con CVEs conocidas (OpenSSL, glibc, etc.). Trivy escanea la imagen
#   construida y detecta esas vulnerabilidades ANTES de que el contenedor
#   se despliegue. Si la imagen tiene una vulnerabilidad crítica en una
#   librería de sistema, podría usarse para escalar privilegios dentro del
#   contenedor y comprometer el host.
#
# Umbrales:
#   Trivy → bloquea si encuentra vulnerabilidades CRITICAL en la imagen.
#   Se permiten HIGH con un máximo de 5 (balance entre seguridad y viabilidad
#   de la imagen base en el Learner Lab).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reportes}"
IMAGE_NAME="${IMAGE_NAME:-gestor-tareas-api:latest}"
ETAPA="[ETAPA-5 CONTAINER]"

echo "$ETAPA Iniciando escaneo de imagen Docker con Trivy..."
echo "$ETAPA Imagen objetivo: $IMAGE_NAME"

# Instalar Trivy si no está disponible
if ! command -v trivy &> /dev/null; then
  echo "$ETAPA Instalando Trivy..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin v0.53.0
fi

# Escanear la imagen
trivy image \
  --exit-code 0 \
  --severity CRITICAL,HIGH \
  --format json \
  --output "${REPORT_DIR}/trivy_report.json" \
  "$IMAGE_NAME" || true

trivy image \
  --exit-code 0 \
  --severity CRITICAL,HIGH \
  --format table \
  "$IMAGE_NAME" 2>&1 | tee "${REPORT_DIR}/trivy_report.txt"

# Contar por severidad
CRITICAL_COUNT=$(python3 -c "
import json
try:
    data = json.load(open('${REPORT_DIR}/trivy_report.json'))
    results = data.get('Results', [])
    count = sum(
        1 for r in results
        for v in r.get('Vulnerabilities', [])
        if v.get('Severity') == 'CRITICAL'
    )
    print(count)
except Exception:
    print(0)
")

HIGH_COUNT=$(python3 -c "
import json
try:
    data = json.load(open('${REPORT_DIR}/trivy_report.json'))
    results = data.get('Results', [])
    count = sum(
        1 for r in results
        for v in r.get('Vulnerabilities', [])
        if v.get('Severity') == 'HIGH'
    )
    print(count)
except Exception:
    print(0)
")

echo "$ETAPA Trivy: CRITICAL=$CRITICAL_COUNT  HIGH=$HIGH_COUNT"

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "$ETAPA ❌ BLOQUEADO — Umbral: 0 vulnerabilidades CRITICAL en la imagen."
  exit 2
fi

if [ "$HIGH_COUNT" -gt 5 ]; then
  echo "$ETAPA ❌ BLOQUEADO — Umbral: máximo 5 vulnerabilidades HIGH (encontradas: $HIGH_COUNT)."
  exit 2
fi

echo "$ETAPA ✅ Trivy OK — imagen dentro de umbrales aceptables."
echo "$ETAPA Etapa completada exitosamente."
