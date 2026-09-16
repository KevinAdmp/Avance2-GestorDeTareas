"""
Cliente RabbitMQ — publica mensajes de recordatorio en la cola.
La creación de la tarea (API) y el envío del recordatorio (worker)
son procesos totalmente desacoplados a través de esta cola.
"""
import json
import logging
import os

import pika

logger = logging.getLogger(__name__)

RABBITMQ_URL = os.environ.get("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
TASK_QUEUE = os.environ.get("TASK_QUEUE", "recordatorios")


def publicar_recordatorio(tarjeta_id: int, titulo: str, fecha_limite: str,
                          usuarios: list) -> bool:
    """
    Publica un mensaje en la cola 'recordatorios' con los datos de
    la tarjeta recién creada. Devuelve True si tuvo éxito.
    """
    mensaje = {
        "tarjeta_id": tarjeta_id,
        "titulo": titulo,
        "fecha_limite": fecha_limite,
        "usuarios": usuarios,
    }
    try:
        params = pika.URLParameters(RABBITMQ_URL)
        connection = pika.BlockingConnection(params)
        channel = connection.channel()

        channel.queue_declare(queue=TASK_QUEUE, durable=True)
        channel.basic_publish(
            exchange="",
            routing_key=TASK_QUEUE,
            body=json.dumps(mensaje),
            properties=pika.BasicProperties(delivery_mode=2),
        )
        connection.close()
        logger.info("Recordatorio publicado para tarjeta %s", tarjeta_id)
        return True
    except Exception as exc:  # pylint: disable=broad-except
        logger.error("No se pudo publicar recordatorio: %s", exc)
        return False
