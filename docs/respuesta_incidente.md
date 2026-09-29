# Respuesta al Incidente
**Autor:** Kevin Adrian Morales Palomo  
**Fecha:** 28 de septiembre de 2026  
**Hallazgo:** CWE-502 en `app/worker/importar_plantilla_tarea.py`

---

## Contención inmediata

El pipeline bloqueó el parche en la Etapa 1 antes de que llegara a ningún ambiente, así que no hubo despliegue que contener. La contención fue automática.

Si el código ya hubiera estado corriendo en producción, lo que haría de inmediato es:

1. Agregar `FEATURE_IMPORTAR_PLANTILLA=false` en el `.env` y hacer que el worker ignore esos mensajes hasta tener el fix listo. Esto detiene el sangrado sin tocar el código.
2. Bloquear el puerto 5672 de RabbitMQ en el Security Group de AWS para que no sea accesible desde fuera de la VPC. Con credenciales `guest:guest` cualquiera podría publicar mensajes maliciosos.
3. Revisar los logs del worker para ver si ya hubo mensajes sospechosos en la cola antes de detectar el problema.

Ninguna de estas acciones corrige la vulnerabilidad, solo reduce el riesgo mientras se prepara el arreglo real.

---

## Prevención

El arreglo fue reemplazar `pickle.loads()` por `json.loads()`.

**Antes:**
```python
import pickle, base64
payload_bytes = base64.b64decode(payload_codificado)
plantilla = pickle.loads(payload_bytes)
```

**Después:**
```python
import json
plantilla = json.loads(payload_codificado)
```

JSON no puede ejecutar código. Solo puede representar strings, números, listas y diccionarios. Eso es exactamente lo que necesita esta función para transferir título, descripción, etiquetas y usuario_id de una plantilla.

También agregué validación de campos obligatorios para que si llega un mensaje incompleto el worker lo rechace con un error claro en lugar de fallar silenciosamente:

```python
CAMPOS_REQUERIDOS = {"titulo", "descripcion", "usuario_id"}
campos_faltantes = CAMPOS_REQUERIDOS - plantilla.keys()
if campos_faltantes:
    raise ValueError(f"Plantilla inválida: faltan campos {campos_faltantes}")
```

La funcionalidad que pedía el producto (importar una plantilla de tarea compartida) quedó completamente funcional con el cambio.

---

## Falsos positivos del código original

Bandit también marcó dos cosas del código original que no son del parche:

- **B110** en `worker.py:110` — un `except: pass` en el bloque de cierre de conexión cuando el worker recibe Ctrl+C. No es explotable, es solo código de limpieza al apagar el proceso.
- **B104** en `wsgi.py:12` — `host="0.0.0.0"` en el arranque de desarrollo. Es necesario para que Docker reciba tráfico. En producción real esto va detrás de un proxy reverso.

Ambos son Low/Medium y el pipeline no los bloquea porque el umbral está en HIGH/CRITICAL.
