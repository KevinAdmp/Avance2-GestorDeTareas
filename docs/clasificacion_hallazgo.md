# Clasificación del Hallazgo de Seguridad
**Proyecto:** Gestor de Tareas Colaborativo — Tema 5  
**Autor:** Kevin Morales  
**Fecha:** 2026-09-28  
**Parche analizado:** `app/worker/importar_plantilla_tarea.py`

---

## Hallazgo

| Campo | Detalle |
|---|---|
| **Archivo** | `app/worker/importar_plantilla_tarea.py`, línea 21 |
| **Regla Bandit** | B301 — `pickle` and modules that wrap it can be unsafe when used to deserialize untrusted data |
| **Regla adicional** | B403 — `import pickle` (importación de módulo inseguro) |
| **CWE** | [CWE-502 — Deserialization of Untrusted Data](https://cwe.mitre.org/data/definitions/502.html) |
| **Herramienta** | Bandit 1.7.9 |
| **Confianza** | High |

### Código afectado

```python
# app/worker/importar_plantilla_tarea.py  líneas 19-21
payload_codificado = mensaje_cola["Body"]
payload_bytes = base64.b64decode(payload_codificado)
plantilla = pickle.loads(payload_bytes)   # ← VULNERABILIDAD
```

El mensaje llega de la cola RabbitMQ (`mensaje_cola["Body"]`). Ese cuerpo es una fuente externa — cualquier actor que pueda publicar en la cola puede controlar el contenido del payload.

---

## Tipo de falla

**Deserialización insegura de datos no confiables (CWE-502).**

El módulo `pickle` de Python puede ejecutar código arbitrario durante la deserialización. A diferencia de JSON, un objeto pickle no es solo datos — es un flujo de instrucciones que el intérprete ejecuta. Si el payload está controlado por un atacante, puede contener instrucciones `__reduce__` que invoquen `os.system`, `subprocess`, o cualquier llamada al sistema con los privilegios del proceso worker.

Ejemplo de exploit mínimo:
```python
import pickle, os, base64

class Exploit(object):
    def __reduce__(self):
        return (os.system, ("rm -rf /data",))

payload = base64.b64encode(pickle.dumps(Exploit())).decode()
# Publicar este payload en la cola → el worker lo ejecuta
```

---

## Severidad

**Alta (High)**

| Dimensión | Evaluación |
|---|---|
| **Impacto** | Ejecución de código arbitrario con los privilegios del proceso worker dentro del contenedor. Un atacante puede leer secretos de entorno, destruir datos, o pivotar a otros servicios en la red Docker. |
| **Facilidad de explotación** | Alta — no requiere autenticación. Solo necesita acceso de escritura a la cola RabbitMQ. En el setup actual, RabbitMQ expone el puerto 5672 con credenciales por defecto (`guest:guest`), lo que hace el exploit trivial desde la red local. |
| **Alcance** | El worker corre en su propio contenedor, pero comparte la red `app-net` con la API y RabbitMQ. Un compromiso del worker permite movimiento lateral. |

> Bandit lo reporta como `Severity: Medium` porque su clasificación es estática y no considera el contexto de ejecución (datos externos vs. internos). En este caso, el payload viene de la cola — una fuente completamente externa — lo que eleva la severidad real a **Alta**.

---

## ¿Es un falso positivo?

**No.**

Se confirmó manualmente que:
1. El campo `mensaje_cola["Body"]` proviene directamente del mensaje de RabbitMQ — dato externo no validado.
2. No existe ninguna capa de autenticación ni firma criptográfica en el mensaje antes de la deserialización.
3. El exploit demostrado arriba se ejecuta tal cual si se publica en la cola.

Bandit reporta Medium en lugar de High porque su análisis es estático y no traza el origen del dato. En el contexto real de esta aplicación, la severidad correcta es **Alta**.

---

## Resumen ejecutivo

El parche recibido introduce una función que deserializa con `pickle.loads()` datos provenientes de la cola de mensajes RabbitMQ. Cualquier actor con acceso a la cola puede publicar un payload malicioso y ejecutar código arbitrario en el servidor worker. El pipeline de CI/CD detectó el hallazgo en la Etapa 1 (Bandit B301, CWE-502) y bloqueó el despliegue antes de que el código llegara al ambiente de QA o Producción.
