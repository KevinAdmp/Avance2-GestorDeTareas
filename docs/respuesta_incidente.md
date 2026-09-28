# Respuesta al Incidente de Seguridad
**Proyecto:** Gestor de Tareas Colaborativo — Tema 5  
**Autor:** Kevin Morales  
**Fecha:** 2026-09-28  
**Hallazgo:** CWE-502 — Deserialización insegura con `pickle.loads()` en parche recibido  
**Archivo afectado:** `app/worker/importar_plantilla_tarea.py`

---

## Contención inmediata

> Lo que se haría AHORA MISMO para frenar el riesgo mientras se prepara el arreglo real.  
> No corrige la causa raíz — solo detiene el sangrado.

**Acción:** El parche **no se desplegó** porque el pipeline lo bloqueó en la Etapa 1 (Bandit B301).  
El código con la vulnerabilidad nunca llegó al ambiente de QA ni a Producción.

Si el código ya hubiera sido desplegado antes de detectar el problema, las acciones de contención serían:

1. **Deshabilitar el endpoint/función de importar plantilla** mediante una bandera de configuración en `.env`:
   ```
   FEATURE_IMPORTAR_PLANTILLA=false
   ```
   Y en el worker, verificar esa bandera antes de procesar mensajes de ese tipo:
   ```python
   if os.environ.get("FEATURE_IMPORTAR_PLANTILLA", "false") != "true":
       channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
       return
   ```

2. **Bloquear el puerto 5672 de RabbitMQ** en el Security Group de AWS para que solo sea accesible desde la IP del servidor, eliminando la posibilidad de que un atacante externo publique mensajes directamente.

3. **Revocar y rotar las credenciales de RabbitMQ** (`guest:guest`) por si ya hubieran sido usadas para publicar payloads maliciosos.

---

## Prevención

> El arreglo real en el código que elimina la causa raíz.  
> Es lo que efectivamente se sube a Producción.

**Causa raíz:** El uso de `pickle.loads()` para deserializar datos de una fuente externa (cola de mensajes). `pickle` puede ejecutar código arbitrario durante la deserialización.

**Solución:** Reemplazar `pickle` por `json` para la serialización/deserialización del payload. JSON solo puede representar tipos de datos primitivos (strings, números, listas, diccionarios) — nunca ejecuta código.

### Cambio en el código

**Antes (vulnerable):**
```python
import pickle
import base64

payload_bytes = base64.b64decode(payload_codificado)
plantilla = pickle.loads(payload_bytes)   # ← ejecuta código arbitrario
```

**Después (seguro):**
```python
import json

plantilla = json.loads(payload_codificado)   # ← solo datos, nunca código
```

Adicionalmente, se agrega validación de campos obligatorios para evitar errores silenciosos:
```python
CAMPOS_REQUERIDOS = {"titulo", "descripcion", "usuario_id"}
if not CAMPOS_REQUERIDOS.issubset(plantilla.keys()):
    raise ValueError(f"Plantilla inválida: faltan campos {CAMPOS_REQUERIDOS - plantilla.keys()}")
```

### Por qué JSON es seguro aquí

- El formato JSON es un estándar de intercambio de datos sin capacidad de ejecución.
- `json.loads()` solo produce `dict`, `list`, `str`, `int`, `float`, `bool` y `None`.
- No existe ningún vector de ataque equivalente al `__reduce__` de pickle en JSON.
- La funcionalidad pedida (transferir título, descripción, etiquetas y usuario_id) se puede representar completamente con JSON.

### Cambio en el publicador (lado que envía el mensaje)

El lado que publica la plantilla en la cola también debe cambiar de pickle a JSON:

**Antes:**
```python
import pickle, base64
payload = base64.b64encode(pickle.dumps(plantilla_dict)).decode()
```

**Después:**
```python
import json
payload = json.dumps(plantilla_dict)
```

---

## Verificación de la remediación

Tras aplicar el fix, Bandit ya no reporta B301 ni B403, y el pipeline completa las 6 etapas en verde.  
Ver evidencia en: `reportes/pipeline_verde.txt`
