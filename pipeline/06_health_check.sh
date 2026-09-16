#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ETAPA 6: Health check del servicio desplegado
#
# Justificación de riesgo:
#   Aunque todas las etapas anteriores pasen, la aplicación podría fallar
#   al arrancar por un error de configuración (variable de entorno faltante,
#   no puede conectarse a RDS o RabbitMQ). Esta etapa verifica que el
#   endpoint /salud responde 200 OK ANTES de declarar la entrega exitosa,
#   garantizando que lo que se sube al repositorio también funciona en
#   tiempo de ejecución.
#
# Umbral:
#   Bloquea si /salud no responde HTTP 200 después de 10 intentos (60s total).
#   Un servicio que no responde no puede considerarse "entregado".
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ETAPA="[ETAPA-6 HEALTH]"
APP_URL="${APP_URL:-http://localhost:5000}"
MAX_RETRIES=10
RETRY_DELAY=6

echo "$ETAPA Verificando endpoint $APP_URL/salud ..."
echo "$ETAPA Máximo $MAX_RETRIES intentos con ${RETRY_DELAY}s de espera entre cada uno."

for i in $(seq 1 $MAX_RETRIES); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/salud" 2>/dev/null || echo "000")
  echo "$ETAPA Intento $i/$MAX_RETRIES — HTTP $HTTP_CODE"

  if [ "$HTTP_CODE" = "200" ]; then
    echo "$ETAPA ✅ Servicio vivo — /salud respondió 200."
    echo "$ETAPA Etapa completada exitosamente."
    exit 0
  fi

  if [ "$i" -lt "$MAX_RETRIES" ]; then
    sleep "$RETRY_DELAY"
  fi
done

echo "$ETAPA ❌ BLOQUEADO — El servicio no respondió 200 después de $MAX_RETRIES intentos."
echo "$ETAPA    Revisa los logs con: docker compose logs api"
exit 2
