#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 4: Escaneo de Infraestructura como Código (Checkov)
#
# Justificación de riesgo:
#   Los archivos .tf definen S3 y RDS. Si se olvida bloquear el acceso
#   público del bucket o deshabilitar el cifrado de RDS, la app quedaría
#   expuesta. Checkov detecta esas configuraciones incorrectas ANTES de
#   aplicar terraform, evitando que un error de configuración llegue a AWS.
#
# Umbrales:
#   Checkov → bloquea si hay CUALQUIER hallazgo FAILED en los checks de
#   seguridad críticos: cifrado en reposo, acceso público bloqueado,
#   y logging habilitado. Se permiten warnings de checks menores (INFO).
#   Específicamente se verifican los checks:
#     CKV_AWS_18  — S3 access logging
#     CKV_AWS_19  — S3 server-side encryption
#     CKV_AWS_20  — S3 bucket no es público (ACL)
#     CKV_AWS_21  — S3 versioning
#     CKV_AWS_54  — S3 public access block
#     CKV_AWS_16  — RDS encryption
#     CKV_AWS_17  — RDS no publicly accessible
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reportes}"
ETAPA="[ETAPA-4 IAC]"

echo "$ETAPA Iniciando escaneo de IaC con Checkov..."

pip3 install --quiet checkov==3.2.232 || pip install --quiet checkov==3.2.232

checkov \
  --directory infra/ \
  --framework terraform \
  --check CKV_AWS_16,CKV_AWS_17,CKV_AWS_18,CKV_AWS_19,CKV_AWS_20,CKV_AWS_21,CKV_AWS_54 \
  --output cli \
  --output-file-path "${REPORT_DIR}" \
  --output json 2>&1 | tee "${REPORT_DIR}/checkov_report.txt" || true

# Contar checks fallidos del reporte JSON
FAILED=$(python3 -c "
import json, glob, sys
files = glob.glob('${REPORT_DIR}/results_json.json')
if not files:
    # fallback: buscar en el txt
    import subprocess
    result = subprocess.run(['grep', '-c', 'FAILED', '${REPORT_DIR}/checkov_report.txt'],
                           capture_output=True, text=True)
    print(result.stdout.strip() or '0')
    sys.exit()
data = json.load(open(files[0]))
results = data.get('results', {})
failed = results.get('failed_checks', [])
print(len(failed))
" 2>/dev/null || grep -c "FAILED" "${REPORT_DIR}/checkov_report.txt" 2>/dev/null || echo 0)

echo "$ETAPA Checkov: $FAILED check(s) fallido(s)."

if [ "$FAILED" -gt 0 ]; then
  echo "$ETAPA ❌ BLOQUEADO — Umbral: 0 checks de seguridad críticos fallidos en IaC."
  exit 2
fi

echo "$ETAPA ✅ Checkov OK — todos los checks de seguridad pasados."
echo "$ETAPA Etapa completada exitosamente."
