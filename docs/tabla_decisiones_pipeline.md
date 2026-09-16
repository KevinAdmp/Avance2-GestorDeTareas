# Tabla de Decisiones del Pipeline

**Proyecto:** Gestor de Tareas Colaborativo  
**Autor:** Kevin Morales  
**Fecha:** 2026-09-16

Esta tabla justifica **por qué** existe cada etapa del pipeline, qué riesgo concreto de **esta aplicación** cubre, con qué umbral bloquea, y qué se decidió no cubrir y por qué.

---

## Etapas del pipeline y su justificación

| # | Etapa | Herramienta | Riesgo concreto que cubre | Umbral de bloqueo | Justificación del umbral |
|---|---|---|---|---|---|
| 1 | Lint y análisis estático | Flake8 + Bandit | La app maneja contraseñas y sesiones. Bandit detecta patrones como `eval()`, strings con contraseñas hardcodeadas, uso de `MD5` para hashing, y consultas SQL construidas por concatenación. Flake8 detecta errores de sintaxis que Python no reporta hasta runtime. | Flake8: cualquier error. Bandit: 0 hallazgos HIGH o CRITICAL. | Un hallazgo HIGH de Bandit en esta app significaría directamente un riesgo de autenticación o inyección. No hay umbral razonable distinto de cero para un sistema con login. |
| 2 | Detección de secretos | detect-secrets | El proyecto usa credenciales AWS (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) y contraseñas de RDS. Si alguna se filtra en un commit (por accidente en `.env`, en un print de depuración, o en un test), cualquiera con acceso al repo puede tomar la infraestructura en AWS Academy. | 0 secretos detectados (tolerancia cero). | Un secreto en el repositorio es un incidente de seguridad inmediato, no un warning. El umbral de cero es el único razonable para credenciales de nube. |
| 3 | SCA (análisis de dependencias) + SBOM | Safety + CycloneDX | Flask, SQLAlchemy, Werkzeug y boto3 tienen historial de CVEs. Por ejemplo, versiones antiguas de Werkzeug tienen vulnerabilidades de path traversal (CVE-2023-25577). Un `pip install` descuidado puede introducir una dependencia vulnerable sin que el desarrollador lo note. | Safety: 0 vulnerabilidades HIGH o CRITICAL en dependencias. CycloneDX: genera el SBOM (no bloquea). | Una vulnerabilidad CRITICAL en Werkzeug o Flask afectaría directamente la API que procesa autenticación y datos de usuarios. El SBOM es exigido por la rúbrica como artefacto de entrega. |
| 4 | Escaneo de IaC | Checkov | El archivo `infra/main.tf` define el bucket S3 y la instancia RDS. Un error de configuración (por ejemplo, olvidar `publicly_accessible = false` en RDS, o no añadir el bloque de acceso público en S3) expondría la base de datos de usuarios o los archivos adjuntos de forma pública en internet. | 0 checks fallidos en los 7 checks de seguridad críticos (CKV_AWS_16, 17, 18, 19, 20, 21, 54). | Los 7 checks cubren exactamente los controles que la rúbrica exige: cifrado y sin acceso público para S3 y RDS. Un fallo en cualquiera de ellos significa que la infraestructura no cumple los requisitos mínimos de seguridad del proyecto. |
| 5 | Escaneo de imagen Docker | Trivy | La imagen base `python:3.12.4-slim` incluye librerías del sistema operativo (OpenSSL, glibc, libpq) que pueden tener CVEs conocidas. Una vulnerabilidad CRITICAL en una librería de sistema podría usarse para escalar privilegios dentro del contenedor. | 0 vulnerabilidades CRITICAL. Máximo 5 HIGH. | CRITICAL = 0 porque una vulnerabilidad crítica en el runtime del contenedor podría comprometer el host. Se permite hasta 5 HIGH como balance pragmático con el ciclo de actualización de la imagen base en el Learner Lab; más de 5 HIGH indica que la imagen base está desactualizada. |
| 6 | Health check del servicio | curl + /salud | Las etapas anteriores validan el código y la configuración estática, pero no garantizan que la aplicación arranque correctamente. Un error de variable de entorno faltante, un fallo de conexión a RDS o un error de import en Python harían que la app no sirva tráfico aunque el código sea correcto. | HTTP 200 en `/salud` después de máximo 10 intentos (60 segundos). | Un servicio que no responde 200 en `/salud` no puede considerarse entregado. El endpoint fue diseñado específicamente para esta verificación (exigido por la rúbrica). |

---

## Riesgos que se decidió NO cubrir y por qué

| Riesgo | Por qué se descartó |
|---|---|
| **DAST** (escaneo dinámico, ZAP, Nikto) | Requiere la app desplegada en un entorno con URL externa accesible. El Learner Lab no garantiza eso. El beneficio no justifica el riesgo de que el pipeline dependa de conectividad externa variable. |
| **Fuzzing de endpoints** | Fuera del alcance del proyecto. El tiempo disponible no permite diseñar un corpus de fuzzing útil para una app de gestión de tareas. |
| **Análisis de composición de licencias** | No hay restricciones de licencia en el proyecto académico. Todas las dependencias son MIT o BSD. |
| **Escaneo de imágenes de dependencias** (RabbitMQ, postgres) | Esas imágenes son de terceros; no se tiene control sobre ellas. Se mitiga usando versiones fijas (`rabbitmq:3.13.4-management-alpine`) en lugar de `:latest`. |
| **Pruebas unitarias automatizadas en el pipeline** | No fueron solicitadas explícitamente. Se priorizaron los controles de seguridad que la rúbrica sí evalúa. |

---

## Veredicto final integrado

El pipeline termina con **un único veredicto** emitido por `pipeline/pipeline.sh`:

- `PERMITIDO` si las 6 etapas pasan sin fallos (corrida verde).
- `BLOQUEADO` en la primera etapa que supere su umbral (corrida roja), con la etapa específica identificada.

La lógica de bloqueo es **fail-fast**: se detiene en la primera etapa fallida para ahorrar tiempo y hacer el problema inmediatamente visible.
