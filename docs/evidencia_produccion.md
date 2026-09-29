# Evidencia de Promoción a Producción
**Autor:** Kevin Adrian Morales Palomo  
**Fecha:** 28 de septiembre de 2026

---

## Ciclo completo QA → Producción

| Paso | Ambiente | Estado |
|---|---|---|
| Parche aplicado sin modificar | QA (EC2 gestor-tareas-qa) | ✅ |
| Pipeline bloqueó el parche — Bandit B301 CWE-502 | QA | ✅ |
| Hallazgo clasificado | QA | ✅ |
| Contención y prevención documentadas | QA | ✅ |
| Código remediado — pickle → json | QA | ✅ |
| Pipeline en verde — 6/6 etapas | QA | ✅ |
| Código remediado desplegado en Producción | EC2 gestor-tareas-produccion | ✅ |

---

## Instancia QA

- **Instance ID:** `i-04b7e403ebf90aa44`
- **Nombre:** `gestor-tareas-qa`
- **IP pública:** `34.229.86.30`
- **Región:** us-east-1
- **Health check:** `http://34.229.86.30:5001/salud` → HTTP 200
- **Contenedores corriendo:** gestor_api, gestor_worker, gestor_rabbitmq
- **Base de datos:** RDS PostgreSQL — `gestor-tareas-db.csey27ukhrwo.us-east-1.rds.amazonaws.com`

---

## Instancia de Producción

- **Instance ID:** `i-0c0ccca6659181ce1`
- **Nombre:** `gestor-tareas-produccion`
- **IP pública:** `98.84.159.9`
- **Región:** us-east-1
- **Health check:** `http://98.84.159.9:5001/salud` → HTTP 200
- **Contenedores corriendo:** gestor_api, gestor_worker, gestor_rabbitmq
- **Base de datos:** misma RDS que QA

---

## Confirmación del ciclo

El código que se desplegó en Producción es exactamente el que pasó el pipeline en verde. El parche con la vulnerabilidad nunca llegó a Producción — fue bloqueado en QA por Bandit B301 (CWE-502) y solo se promovió la versión ya remediada.

- Commit de remediación: `ebf3bc8` — `pickle.loads()` → `json.loads()`
- Pipeline verde: 6/6 etapas PASS — ver `reportes/pipeline_verde.txt`
- Pipeline bloqueado: ver `reportes/pipeline_bloqueado.txt`
