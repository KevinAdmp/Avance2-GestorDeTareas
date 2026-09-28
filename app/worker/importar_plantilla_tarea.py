"""
PARCHE REMEDIADO - Importar una plantilla de tarea compartida
Tema: Gestor de tareas colaborativo

Remediación aplicada (2026-09-28):
  Se reemplazó pickle.loads() por json.loads() para eliminar la
  vulnerabilidad CWE-502 (Deserialization of Untrusted Data).
  JSON solo puede representar datos primitivos — nunca ejecuta código,
  a diferencia de pickle que puede invocar __reduce__ con código arbitrario.

  El publicador del mensaje debe enviar el payload como JSON puro
  (no base64+pickle), lo que mantiene la funcionalidad completa.
"""
import json
import logging

logger = logging.getLogger(__name__)

# Campos obligatorios que debe tener toda plantilla válida
CAMPOS_REQUERIDOS = {"titulo", "descripcion", "usuario_id"}


def crear_tarea_desde_plantilla(titulo, descripcion, etiquetas, usuario_id):
    """
    Crea una tarea a partir de los datos de una plantilla.
    Integración con el modelo Tarjeta de la app Flask.
    En producción real, esta función importaría y usaría db + Tarjeta.
    """
    logger.info(
        "Creando tarea desde plantilla — título: %s, usuario_id: %s",
        titulo, usuario_id
    )
    return {
        "titulo": titulo,
        "descripcion": descripcion,
        "etiquetas": etiquetas,
        "usuario_id": usuario_id,
    }


def procesar_mensaje_plantilla(mensaje_cola):
    """
    Consume un mensaje de la cola con una plantilla de tarea en formato JSON
    y crea la tarea correspondiente para el usuario que la importa.

    REMEDIACIÓN: Se usa json.loads() en lugar de pickle.loads().
    json.loads() solo deserializa datos primitivos y nunca ejecuta código,
    eliminando el riesgo de ejecución remota de código (CWE-502).
    """
    payload_codificado = mensaje_cola["Body"]

    # REMEDIADO: json.loads() — seguro, no ejecuta código arbitrario
    # ORIGINAL VULNERABLE: pickle.loads(base64.b64decode(payload_codificado))
    plantilla = json.loads(payload_codificado)

    # Validar campos obligatorios antes de procesar
    campos_faltantes = CAMPOS_REQUERIDOS - plantilla.keys()
    if campos_faltantes:
        raise ValueError(
            f"Plantilla inválida: faltan campos obligatorios {campos_faltantes}"
        )

    tarea = crear_tarea_desde_plantilla(
        titulo=plantilla["titulo"],
        descripcion=plantilla["descripcion"],
        etiquetas=plantilla.get("etiquetas", []),
        usuario_id=plantilla["usuario_id"],
    )

    return tarea
