# Clasificación del Hallazgo
**Autor:** Kevin Adrian Morales Palomo  
**Fecha:** 28 de septiembre de 2026  
**Archivo:** `app/worker/importar_plantilla_tarea.py`

---

## Qué encontré

Bandit detectó dos problemas en el parche recibido:

- **B403** en línea 10: importación del módulo `pickle`
- **B301** en línea 21: uso de `pickle.loads()` con datos que vienen de la cola

El código problemático es este:

```python
payload_bytes = base64.b64decode(payload_codificado)
plantilla = pickle.loads(payload_bytes)
```

El dato `payload_codificado` viene de `mensaje_cola["Body"]` — es decir, del cuerpo de un mensaje de RabbitMQ. Eso es una fuente externa que cualquiera puede controlar si tiene acceso a la cola.

---

## Tipo de falla

**Deserialización insegura — CWE-502**

El problema con `pickle` es que no solo lee datos, ejecuta instrucciones. Cuando haces `pickle.loads()` con un objeto que alguien más construyó, ese objeto puede tener un método `__reduce__` que corre cualquier comando del sistema. No es una vulnerabilidad teórica — con menos de 10 líneas de Python se puede armar un payload que ejecute lo que sea en el servidor.

---

## Severidad

Le di severidad **Alta**, aunque Bandit la reporta como Medium.

Bandit hace análisis estático y no sabe si el dato es interno o externo. En este caso el dato viene de RabbitMQ, que en el setup actual tiene credenciales por defecto (`guest:guest`) y el puerto 5672 abierto. Cualquiera en la red puede publicar mensajes. Eso hace que el exploit sea trivial, no teórico.

El impacto también es alto: si alguien explota esto puede leer las variables de entorno del contenedor (donde están las llaves de AWS y la contraseña de RDS), borrar datos, o moverse a otros contenedores en la misma red Docker.

---

## ¿Es falso positivo?

No. Verifiqué manualmente que `mensaje_cola["Body"]` viene directo del mensaje de la cola sin ninguna validación previa. No hay firma, no hay autenticación, no hay lista blanca. El hallazgo es real.

Los otros dos hallazgos que marcó Bandit (B110 y B104) sí los consideré falsos positivos porque son del código original y no son explotables en este contexto — los detallo en la respuesta al incidente.
