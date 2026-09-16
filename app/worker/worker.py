"""
Worker de recordatorios — Tema 5: Gestor de tareas colaborativo.

Pieza técnica distintiva obligatoria:
  Una cola de mensajes (RabbitMQ en contenedor) que desacopla
  la creación de la tarea del envío del recordatorio.

Este proceso corre en su PROPIO contenedor, completamente separado
de la API Flask. Consume mensajes de la cola 'recordatorios' y
"envía" el aviso (en esta simulación: lo escribe en un log con marca
de tiempo). En producción real se reemplazaría el print por una
llamada a un servicio de correo / push / SMS.

Flujo:
  API Flask  →  publica mensaje en RabbitMQ  →  Worker consume  →  log de recordatorio
"""
import json
import logging
import os
import sys
import time
from datetime import datetime, timezone

import pika
from dotenv import load_dotenv

load_dotenv()

# ── Configuración ────────────────────────────────────────────────────────────
RABBITMQ_URL  = os.environ.get("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
TASK_QUEUE    = os.environ.get("TASK_QUEUE", "recordatorios")
RECONNECT_DELAY = int(os.environ.get("RECONNECT_DELAY", "5"))   # segundos

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  [WORKER]  %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


# ── Lógica de recordatorio ───────────────────────────────────────────────────
def procesar_recordatorio(datos: dict) -> None:
    """
    Simula el envío de un recordatorio.
    Escribe el aviso en stdout (log estructurado).
    En un sistema real aquí iría boto3 SES / Twilio / SMTP.
    """
    tarjeta_id   = datos.get("tarjeta_id", "?")
    titulo       = datos.get("titulo", "Sin título")
    fecha_limite = datos.get("fecha_limite", "Sin fecha")
    usuarios     = datos.get("usuarios", [])

    ahora = datetime.now(timezone.utc).isoformat()

    logger.info("=" * 60)
    logger.info("RECORDATORIO ENVIADO")
    logger.info("  Tarjeta ID  : %s", tarjeta_id)
    logger.info("  Título      : %s", titulo)
    logger.info("  Fecha límite: %s", fecha_limite)
    logger.info("  Destinatarios: %s", ", ".join(usuarios) if usuarios else "ninguno")
    logger.info("  Procesado en: %s", ahora)
    logger.info("=" * 60)


# ── Callback de RabbitMQ ─────────────────────────────────────────────────────
def on_message(channel, method, _properties, body: bytes) -> None:
    try:
        datos = json.loads(body.decode("utf-8"))
        logger.info("Mensaje recibido: tarjeta_id=%s", datos.get("tarjeta_id"))
        procesar_recordatorio(datos)
        channel.basic_ack(delivery_tag=method.delivery_tag)
    except json.JSONDecodeError as exc:
        logger.error("Mensaje con JSON inválido: %s — %s", body, exc)
        channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
    except Exception as exc:  # pylint: disable=broad-except
        logger.error("Error procesando mensaje: %s", exc)
        channel.basic_nack(delivery_tag=method.delivery_tag, requeue=True)


# ── Bucle principal con reconexión automática ────────────────────────────────
def run() -> None:
    logger.info("Worker de recordatorios iniciando...")
    logger.info("Conectando a RabbitMQ: %s  cola: %s", RABBITMQ_URL, TASK_QUEUE)

    while True:
        try:
            params     = pika.URLParameters(RABBITMQ_URL)
            connection = pika.BlockingConnection(params)
            channel    = connection.channel()

            channel.queue_declare(queue=TASK_QUEUE, durable=True)
            channel.basic_qos(prefetch_count=1)   # procesar de uno en uno
            channel.basic_consume(queue=TASK_QUEUE, on_message_callback=on_message)

            logger.info("Esperando mensajes en la cola '%s'. Ctrl+C para salir.", TASK_QUEUE)
            channel.start_consuming()

        except pika.exceptions.AMQPConnectionError as exc:
            logger.warning(
                "RabbitMQ no disponible (%s). Reintentando en %ds...",
                exc, RECONNECT_DELAY,
            )
            time.sleep(RECONNECT_DELAY)
        except KeyboardInterrupt:
            logger.info("Worker detenido por el usuario.")
            try:
                connection.close()
            except Exception:  # pylint: disable=broad-except
                pass
            sys.exit(0)
        except Exception as exc:  # pylint: disable=broad-except
            logger.error("Error inesperado: %s. Reintentando en %ds...", exc, RECONNECT_DELAY)
            time.sleep(RECONNECT_DELAY)


if __name__ == "__main__":
    run()
