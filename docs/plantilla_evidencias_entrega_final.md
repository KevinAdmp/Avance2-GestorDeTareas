# Entrega Final del Reto · Documento de Evidencias
## De QA a Producción

---

## Datos del alumno

| Dato | Respuesta |
|---|---|
| Nombre completo | Kevin Morales |
| Matrícula | [COMPLETAR] |
| Tema | 5 — Gestor de tareas colaborativo |
| Enlace al repositorio Git (con commit de remediación) | https://github.com/KevinAdmp/Avance2-GestorDeTareas |
| Enlace o IP de instancia de Producción | http://[IP-EC2]:5001 |

---

## Parte 1 · Capturas obligatorias

### 1.1 · Pipeline BLOQUEANDO el parche
**Qué se ve:** La corrida en rojo sobre QA — Bandit B301 detuvo el despliegue
antes de que el código llegara a ningún ambiente.

[INSERTAR CAPTURA DEL ARCHIVO reportes/pipeline_bloqueado.txt]

---

### 1.2 · El hallazgo real en la salida de Bandit
**Qué se ve:** El fragmento exacto de Bandit donde aparece B301 pickle.loads()

```
>> Issue: [B301:blacklist] Pickle and modules that wrap it can be
   unsafe when used to deserialize untrusted data, possible security issue.
   Severity: Medium   Confidence: High
   CWE: CWE-502 (https://cwe.mitre.org/data/definitions/502.html)
   Location: app/worker/importar_plantilla_tarea.py:21:16
   20
   21     plantilla = pickle.loads(payload_bytes)
```

[INSERTAR CAPTURA de la terminal o del archivo reportes/pipeline_bloqueado.txt]

---

### 1.3 · Commit de remediación
**Qué se ve:** Diff en GitHub mostrando antes (pickle) y después (json)

URL del commit: https://github.com/KevinAdmp/Avance2-GestorDeTareas/commit/c2ce369

[INSERTAR CAPTURA del diff en GitHub]

---

### 1.4 · Pipeline PERMITIENDO — ya remediado
**Qué se ve:** Corrida verde completa — las 6 etapas en PASS

```
✅ PASS  Etapa 1 — Lint y análisis estático (Flake8+Bandit)
✅ PASS  Etapa 2 — Detección de secretos (detect-secrets)
✅ PASS  Etapa 3 — SCA y SBOM (Safety+CycloneDX)
✅ PASS  Etapa 4 — Escaneo IaC (Checkov) — 7/7 checks
✅ PASS  Etapa 5 — Escaneo imagen Docker (Trivy)
✅ PASS  Etapa 6 — Health check /salud (HTTP 200)

VEREDICTO: PERMITIDO
```

[INSERTAR CAPTURA del archivo reportes/pipeline_verde.txt]

---

### 1.5 · Instancia de QA (ambiente local + RDS)
**Qué se ve:** Terminal con `docker ps` mostrando los 3 contenedores corriendo
y `curl http://localhost:5001/salud` respondiendo 200.

[INSERTAR CAPTURA]

---

### 1.6 · Instancia de Producción nueva
**Qué se ve:** Consola de AWS mostrando la EC2 nueva en estado "Running"
con Instance ID y IP pública visibles.

[INSERTAR CAPTURA]

---

### 1.7 · App remediada corriendo en Producción
**Qué se ve:** La app funcionando en `http://[IP-EC2]:5001` — pantalla de
tableros o el health check respondiendo desde la instancia de Producción.

[INSERTAR CAPTURA]

---

## Parte 2 · Autoevaluación del flujo completo

| Paso | Cumplido | Notas |
|---|---|---|
| 1. Apliqué el parche en mi instancia de QA | X | `app/worker/importar_plantilla_tarea.py` copiado exactamente como lo entregó el instructor, sin modificar |
| 2. Mi pipeline detuvo el despliegue por el parche | X | Bandit B301 CWE-502 bloqueó en Etapa 1 — ver `reportes/pipeline_bloqueado.txt` |
| 3. Clasifiqué el hallazgo (tipo, severidad, justificación) | X | Ver `docs/clasificacion_hallazgo.md` — CWE-502, severidad Alta |
| 4. Documenté contención inmediata y prevención por separado | X | Ver `docs/respuesta_incidente.md` — dos secciones explícitas |
| 5. Remedié la causa raíz en el código (no un parche cosmético) | X | `pickle.loads()` reemplazado por `json.loads()` — funcionalidad preservada |
| 6. Mi pipeline pasó en verde con el código remediado | X | 6/6 etapas PASS — ver `reportes/pipeline_verde.txt` |
| 7. Promoví el código remediado a mi instancia de Producción | X | EC2 nueva en AWS Academy — ver capturas 1.6 y 1.7 |

---

## Parte 3 · Clasificación en mis palabras

### 3.1 ¿Qué tipo de falla era y por qué la clasificaste así?

La falla es **deserialización insegura de datos no confiables (CWE-502)**. El parche
recibido usaba `pickle.loads()` para deserializar el campo `Body` de un mensaje de
RabbitMQ. A diferencia de JSON, `pickle` no solo interpreta datos — ejecuta
instrucciones durante la deserialización a través del método `__reduce__`. Cualquier
actor que pueda publicar en la cola puede construir un payload pickle que ejecute
comandos arbitrarios en el servidor worker con los privilegios del proceso.

Lo clasifiqué como CWE-502 porque el patrón exacto es: dato externo (la cola) +
`pickle.loads()` sin validación previa = ejecución de código arbitrario controlada
por el atacante.

### 3.2 ¿Qué severidad le diste y qué la justifica?

**Severidad: Alta**

Bandit lo reporta como Medium, pero en el contexto real de esta aplicación la
severidad es Alta por dos razones:

1. **Impacto:** Un exploit exitoso da ejecución de código arbitrario con los
   privilegios del proceso worker dentro del contenedor. El atacante puede leer
   variables de entorno (credenciales AWS, contraseña RDS), destruir datos o
   moverse lateralmente a otros servicios en la red Docker.

2. **Facilidad de explotación:** RabbitMQ en este setup usa credenciales por defecto
   (`guest:guest`) y expone el puerto 5672. Cualquiera en la red local puede publicar
   mensajes. El exploit requiere menos de 10 líneas de Python.

### 3.3 ¿Tu herramienta marcó algo que consideraste falso positivo?

Sí, dos hallazgos del código original (no del parche):

- **B110** (`worker.py:110`) — `except: pass` en el bloque de cierre de conexión al
  recibir Ctrl+C. No es explotable: es código de limpieza que solo se ejecuta al
  apagar el proceso intencionalmente. Falso positivo real.

- **B104** (`wsgi.py:12`) — `host="0.0.0.0"`. Necesario para que el contenedor Docker
  reciba tráfico externo. No aplica en producción real donde un proxy reverso
  (nginx/ALB) intercepta las peticiones. Falso positivo en este contexto.

Ambos son Low/Medium con el umbral del pipeline ajustado a 0 HIGH/CRITICAL, por lo
que no bloquean y están correctamente documentados.

---

## Parte 4 · Contención y prevención

### 4.1 ¿Qué hiciste de contención inmediata?

El pipeline bloqueó el parche **antes de que llegara a ningún ambiente** (ni QA ni
Producción). La contención fue automática: el pipeline detuvo el despliegue en la
Etapa 1.

Si el código ya hubiera estado desplegado, la contención inmediata habría sido:
1. Deshabilitar el endpoint con la bandera `FEATURE_IMPORTAR_PLANTILLA=false` en `.env`
2. Bloquear el puerto 5672 de RabbitMQ en el Security Group de AWS para eliminar
   el vector de ataque externo
3. Rotar credenciales de RabbitMQ (`guest:guest`) por si hubiesen sido usadas

### 4.2 ¿Qué hiciste de prevención (el arreglo real)?

Reemplacé `pickle.loads()` por `json.loads()` en `app/worker/importar_plantilla_tarea.py`.

**Antes (vulnerable):**
```python
import pickle, base64
payload_bytes = base64.b64decode(payload_codificado)
plantilla = pickle.loads(payload_bytes)  # ejecuta código arbitrario
```

**Después (seguro):**
```python
import json
plantilla = json.loads(payload_codificado)  # solo datos, nunca código
```

Adicionalmente agregué validación de campos obligatorios para evitar errores
silenciosos:
```python
CAMPOS_REQUERIDOS = {"titulo", "descripcion", "usuario_id"}
campos_faltantes = CAMPOS_REQUERIDOS - plantilla.keys()
if campos_faltantes:
    raise ValueError(f"Plantilla inválida: faltan campos {campos_faltantes}")
```

La funcionalidad pedida (importar plantilla con título, descripción, etiquetas y
usuario_id) se preserva completamente. JSON puede representar todos esos tipos de
datos sin necesidad de pickle.

---

## Parte 5 · Lo que me costó

### 5.1 ¿Qué fue lo más difícil de encontrar o entender de esta falla?

Lo más difícil fue entender **por qué pickle es peligroso con datos externos** y no
solo "inseguro en general". El código se ve inocente a primera vista: recibe un
mensaje de la cola, lo decodifica en base64 y lo deserializa. El problema no está
en el código en sí sino en el origen del dato — si viene de una fuente externa no
controlada, `pickle` convierte ese dato en un vector de ejecución de código.

La clave fue confirmar manualmente que `mensaje_cola["Body"]` es exactamente eso:
datos externos, no internos. Eso es lo que eleva la severidad de Medium (como la
clasifica Bandit estáticamente) a Alta en el contexto real.

### 5.2 Si esto pasara en producción real con usuarios reales, ¿qué harías distinto?

Tres cosas concretas:

1. **Nunca usar pickle para datos entre servicios.** El estándar para mensajería es
   JSON, protobuf o MessagePack — formatos que solo pueden representar datos, no
   ejecutar código. Esta regla debería estar en el onboarding de cualquier equipo.

2. **Agregar una etapa de revisión de código antes del merge.** El pipeline detectó
   la falla, pero un code review habría evitado que llegara al pipeline. En producción
   real, un segundo par de ojos en cualquier código que toque deserialización es
   obligatorio.

3. **Firmar criptográficamente los mensajes de la cola.** Si los mensajes deben
   incluir datos estructurados complejos, la solución correcta es firmarlos con HMAC
   para verificar que vienen de una fuente confiable antes de procesarlos.
