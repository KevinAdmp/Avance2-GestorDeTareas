# Declaración de Uso de Inteligencia Artificial — Entrega Final

**Proyecto:** Gestor de Tareas Colaborativo — Tema 5  
**Autor:** Kevin Morales  
**Entrega:** Entrega Final del Reto — LSCA2314 · Periodo AD26  
**Fecha:** 2026-09-28

---

## Qué herramientas de IA se usaron

- **Kiro (Claude)** — asistente de programación integrado en el IDE, usado durante toda la entrega.

---

## Qué generó la IA

| Tarea | Participación de la IA |
|---|---|
| Integración del parche en la estructura del proyecto | Identificó dónde colocar el archivo dentro del worker |
| Ejecución del pipeline y captura de evidencia | Ejecutó los comandos y formateó la salida en `pipeline_bloqueado.txt` |
| Redacción de `docs/clasificacion_hallazgo.md` | Generó la estructura y el contenido técnico del documento |
| Redacción de `docs/respuesta_incidente.md` | Generó contención y prevención con ejemplos de código |
| Remediación del código (pickle → json) | Propuso y aplicó el reemplazo con validación de campos |
| Actualización de `.env` y `docker-compose.yml` para RDS | Realizó los cambios de configuración |
| Redacción de `docs/evidencia_produccion.md` | Generó la estructura del documento |

---

## Qué decidí y revisé yo

| Decisión | Justificación personal |
|---|---|
| Confirmar que B301 no es falso positivo | Verifiqué manualmente que `mensaje_cola["Body"]` es dato externo no confiable — la cola es accesible desde la red |
| Elevar la severidad de Medium a Alta | Bandit clasifica estáticamente; el contexto real (dato externo + credenciales default en RabbitMQ) hace el exploit trivial |
| Elegir JSON como remediación en lugar de otras alternativas (msgpack, protobuf) | JSON es el estándar de la cola RabbitMQ en este proyecto — no introduce dependencias nuevas y elimina la causa raíz |
| Mantener la funcionalidad del parche | El profe indica explícitamente que no se debe comentar ni borrar la función — hay que corregir la causa raíz |
| Validar campos obligatorios en el remedio | Decisión de hardening adicional: una plantilla sin `titulo` o `usuario_id` causaría errores silenciosos |
| Conectar RDS real en lugar de Postgres local | Corrección directa del error señalado por el profe en la retroalimentación del Avance 2 |

---

## Lo que no delegué a la IA

- La lectura e interpretación de los comentarios del profe sobre el Avance 2
- La decisión de qué constituye un falso positivo en el contexto de esta aplicación
- La comprensión del flujo completo de QA → remediación → Producción
- Las credenciales y configuración de AWS Academy (endpoint RDS, Security Groups)

---

## Reflexión

El uso de IA en esta entrega aceleró la generación de documentación técnica y la ejecución de comandos del pipeline. Sin embargo, las decisiones de clasificación de severidad, la identificación de falsos positivos y la justificación de por qué JSON es la remediación correcta (y no simplemente eliminar la función) requirieron comprensión real del problema. La IA fue un asistente de implementación, no un tomador de decisiones.
