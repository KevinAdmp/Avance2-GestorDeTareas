# Declaración de Uso de Inteligencia Artificial

**Proyecto:** Gestor de Tareas Colaborativo — Avance 2  
**Materia:** LSCA2314 Herramientas de Tecnologías de Información  
**Autor:** Kevin Morales  
**Fecha:** 2026-09-16

---

## ¿Qué herramientas de IA utilicé?

Utilicé **Kiro (Claude)** como asistente de programación integrado en el IDE para apoyar la generación de código.

---

## ¿En qué usé la IA y en qué no?

### Lo que la IA generó o apoyó

| Componente | Aporte de la IA |
|---|---|
| Estructura de carpetas del repositorio | Propuso la organización `app/`, `infra/`, `pipeline/`, `docs/`, `reportes/` alineada con los requisitos. |
| Modelos SQLAlchemy (`models.py`) | Generó los modelos `Usuario`, `Tablero`, `Tarjeta`, `Asignacion` con relaciones y constraints. |
| Blueprints de rutas Flask | Generó la estructura de los blueprints `auth`, `tableros`, `tarjetas`, `health`. |
| Templates HTML (Jinja2 + Bootstrap) | Generó los 9 templates del frontend. |
| Cliente RabbitMQ (`queue_client.py`) | Generó la función `publicar_recordatorio` con manejo de conexión y propiedades de persistencia. |
| Worker de recordatorios (`worker.py`) | Generó el consumer RabbitMQ con reconexión automática y manejo de errores. |
| Dockerfiles endurecidos | Propuso la estructura con usuario sin privilegios, `HEALTHCHECK`, versión fija de imagen base y `PIP_NO_CACHE_DIR`. |
| `docker-compose.yml` | Generó la configuración de 3 servicios con `depends_on` y `healthcheck`. |
| `infra/main.tf` | Generó el recurso S3 con `public_access_block`, cifrado KMS y versioning; y el recurso RDS con `storage_encrypted`, `publicly_accessible = false` y subnet group. |
| Scripts de pipeline (`01` a `06`) | Generó los scripts bash con los umbrales, la lógica de conteo de hallazgos y los comentarios de justificación. |
| `pipeline.sh` orquestador | Generó el script con tabla de resumen, veredicto final integrado y lógica fail-fast. |
| Documentación (`README.md`, `ADR-001`, `tabla_decisiones_pipeline.md`) | Generó los borradores de los documentos. |

### Lo que yo revisé, corregí y tomé como decisión propia

| Aspecto | Mi intervención |
|---|---|
| **Elección del tema** | Decidí el Tema 5 (Gestor de tareas colaborativo) y la tecnología de cola (RabbitMQ en contenedor vs SQS). |
| **Umbrales del pipeline** | Revisé cada umbral propuesto y lo validé contra los riesgos reales del proyecto. Por ejemplo, el límite de 5 HIGH en Trivy lo justifiqué yo considerando las limitaciones del Learner Lab. |
| **Modelo de datos** | Verifiqué que los modelos reflejan correctamente la lógica del negocio (una tarjeta pertenece a un tablero, una asignación une tarjeta y usuario). |
| **Seguridad de autenticación** | Confirmé que las contraseñas se almacenan con hash (PBKDF2) y que `SECRET_KEY` viene de variable de entorno, nunca hardcodeada. |
| **Selección de imagen base** | Justifiqué `python:3.12.4-slim` sobre Alpine (incompatibilidad con psycopg2-binary) y sobre la imagen full (superficie de ataque innecesaria). |
| **Variables de entorno** | Revisé que ningún archivo del repositorio contiene valores reales de credenciales. |
| **Coherencia entre código y documentación** | Verifiqué que el diagrama de arquitectura, el README y el ADR describen lo que realmente existe en el código. |

---

## Comprensión de lo entregado

Entiendo el funcionamiento de cada componente:

- El worker consume mensajes de RabbitMQ usando `basic_consume` con `basic_ack` después de procesar exitosamente y `basic_nack` con `requeue=False` en caso de mensaje malformado.
- El pipeline usa `exit 2` (no `exit 1`) para señalar bloqueo, lo que en Jenkins y en el script orquestador diferencia un fallo de pipeline de un error inesperado del script.
- Checkov verifica los checks `CKV_AWS_16/17` (RDS cifrado y sin acceso público) y `CKV_AWS_19/54` (S3 cifrado y acceso público bloqueado) porque esos checks cubren exactamente los dos recursos que define `infra/main.tf`.
- La URL prefirmada de S3 tiene expiración de 1 hora para que el bucket permanezca privado pero el usuario pueda descargar el adjunto temporalmente.

---

## Declaración final

El uso de IA en este proyecto fue una herramienta de productividad, no un reemplazo del razonamiento. Cada decisión técnica fue revisada, validada y puedo justificarla en una conversación directa con el profesor.
