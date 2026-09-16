#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 2: Detección de secretos en el repositorio (detect-secrets)
#
# Justificación de riesgo:
#   El proyecto usa credenciales AWS y contraseñas de BD. Si alguna clave
#   se filtra al repositorio (por accidente, en un .env olvidado o en un
#   string hardcodeado), cualquier persona con acceso al repo puede tomar
#   el control de la infraestructura en AWS Academy.
#
# Umbral:
#   Bloquea si detect-secrets encuentra CUALQUIER secreto potencial.
#   Tolerancia cero: un secreto real en el repo es un incidente de seguridad.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reportes}"
ETAPA="[ETAPA-2 SECRETS]"

echo "$ETAPA Iniciando escaneo de secretos..."

pip3 install --quiet detect-secrets==1.5.0 || pip install --quiet detect-secrets==1.5.0

# Escanear todo el repo, excluir carpetas que no son código
detect-secrets scan \
  --exclude-files '\.env\.example$' \
  --exclude-files 'reportes/.*' \
  --exclude-files '.*\.txt$' \
  . > "${REPORT_DIR}/secrets_scan.json"

# Contar resultados positivos
SECRET_COUNT=$(python3 -c "
import json, sys
data = json.load(open('${REPORT_DIR}/secrets_scan.json'))
total = sum(len(v) for v in data.get('results', {}).values())
print(total)
")

echo "$ETAPA Secretos potenciales detectados: $SECRET_COUNT"

if [ "$SECRET_COUNT" -gt 0 ]; then
  echo "$ETAPA ❌ BLOQUEADO — Se encontraron $SECRET_COUNT posible(s) secreto(s) en el código."
  echo "$ETAPA Revisa el archivo ${REPORT_DIR}/secrets_scan.json para ver la ubicación exacta."
  exit 2
fi

echo "$ETAPA ✅ Sin secretos detectados."
echo "$ETAPA Etapa completada exitosamente."
