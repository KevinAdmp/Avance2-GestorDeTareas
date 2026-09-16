# ADR-001 — Decisiones Técnicas del Gestor de Tareas Colaborativo

**Fecha:** 2026-09-16  
**Estado:** Aceptado  
**Autor:** Kevin Morales  
**Tema:** 5 — Gestor de tareas colaborativo (LSCA2314 Avance 2)

---

## Contexto

Se necesita construir una aplicación web de gestión de tareas colaborativa que cumpla los requisitos del Avance 2: backend en Python, al menos 2 contenedores propios, bucket S3, RDS, autenticación, endpoint `/salud`, IaC y un pipeline DevSecOps propio. La pieza técnica distintiva obligatoria del Tema 5 es una **cola de mensajes que desacople la creación de la tarea del envío del recordatorio**.

---

## Decisiones

### 1. Framework backend: Flask

**Elegido sobre:** FastAPI, Django

**Por qué Flask:**
FastAPI tiene ventajas en APIs puras (tipado, OpenAPI automático), pero este proyecto incluye un frontend HTML que se sirve desde el mismo proceso. Flask con Jinja2 es más directo para ese caso, tiene una curva de adopción menor y el equipo de curso (y los ejemplos de la Actividad 4) trabajan con Flask. Django fue descartado por ser excesivamente pesado para el alcance del proyecto.

**Consecuencia aceptada:** Se pierde la documentación automática de FastAPI. Se mitiga con el README y el diagrama de arquitectura.

---

### 2. Cola de mensajes: RabbitMQ en contenedor

**Elegido sobre:** AWS SQS (AWS Academy), Redis Streams

**Por qué RabbitMQ:**
Las instrucciones del Tema 5 mencionan explícitamente "SQS de AWS Academy **o** RabbitMQ en contenedor". Se eligió RabbitMQ porque:
- No depende de credenciales de AWS (el Learner Lab expira y reinicia la sesión frecuentemente).
- Corre completamente en local junto con los demás servicios en `docker-compose`.
- La consola de administración (puerto 15672) facilita demostrar en el video que la cola existe y tiene mensajes.
- El protocolo AMQP con `pika` es estándar y documentado.

**Descartado:** SQS requeriría manejar credenciales rotativas de AWS Academy para el worker, añadiendo complejidad operativa sin beneficio técnico adicional para este alcance.

---

### 3. Base de datos: PostgreSQL en RDS

**Elegido sobre:** MySQL en RDS, SQLite local

**Por qué PostgreSQL:**
PostgreSQL es el motor que AWS Academy provee con menor fricción en el Learner Lab. SQLite fue descartado porque la rúbrica exige RDS real; no es una opción válida. MySQL habría funcionado igual, pero PostgreSQL tiene mejor soporte nativo en SQLAlchemy y psycopg2 es la librería más estable para Python.

---

### 4. ORM: SQLAlchemy con Flask-SQLAlchemy

**Elegido sobre:** queries SQL puras, Peewee, Tortoise ORM

**Por qué SQLAlchemy:**
Es el estándar de facto para Flask. Permite definir los modelos en Python (usuarios, tableros, tarjetas, asignaciones) sin escribir SQL crudo, reduciendo el riesgo de inyección SQL. Las queries parametrizadas son automáticas.

---

### 5. Autenticación: Flask-Login con hash bcrypt (Werkzeug)

**Elegido sobre:** JWT, OAuth, sesiones manuales

**Por qué Flask-Login:**
El requisito es "registro e inicio de sesión aunque sean simples". Flask-Login maneja la sesión del usuario con una cookie firmada por `SECRET_KEY`. Las contraseñas se almacenan con `generate_password_hash` de Werkzeug (PBKDF2 + SHA-256 con salt). JWT habría añadido complejidad innecesaria para una app con frontend HTML.

**Lo que se decidió NO cubrir:** OAuth / inicio de sesión social. El alcance no lo requiere y añadiría dependencias adicionales.

---

### 6. Almacenamiento de archivos: S3 con URL prefirmada

**Elegido sobre:** sistema de archivos local, EFS

**Por qué S3 con URL prefirmada:**
El requisito exige un bucket S3 real que la aplicación use de verdad. Los archivos adjuntos se suben desde la API directamente a S3 con `boto3`. Para servirlos al usuario se genera una URL prefirmada con expiración de 1 hora, garantizando que el bucket permanece privado en todo momento.

---

### 7. Imagen Docker base: python:3.12.4-slim

**Elegido sobre:** python:3.12.4-alpine, python:3.12.4 (full)

**Por qué slim:**
Alpine tiene problemas de compatibilidad con `psycopg2-binary` (requiere compilar libpq) y con algunas dependencias de C. La imagen full incluye compiladores y herramientas de desarrollo que no son necesarias en producción y amplían la superficie de ataque. `slim` es el balance correcto: sin compiladores, con libc estándar compatible con todos los paquetes Python binarios.

---

### 8. Pipeline DevSecOps: 6 etapas con scripts bash + Jenkinsfile

**Elegido sobre:** GitHub Actions, GitLab CI, script único monolítico

**Por qué scripts bash orquestados:**
El Learner Lab no garantiza conectividad a GitHub Actions o GitLab CI desde la instancia EC2. Scripts bash son portables y corren en cualquier entorno (local, Jenkins, cualquier CI). Se acompaña con un Jenkinsfile declarativo para entornos con Jenkins disponible.

**Por qué 6 etapas y no más/menos:**
- Menos etapas habría dejado sin cubrir riesgos reales (secretos en código, CVEs en imagen).
- Más etapas (DAST, fuzzing) son desproporcionadas para el alcance del proyecto y el tiempo disponible.
- Las 6 etapas cubren los riesgos más probables del proyecto específico (ver `tabla_decisiones_pipeline.md`).

---

## Decisiones sobre lo que NO se cubre

| Qué | Por qué se descartó |
|---|---|
| DAST (ZAP, Nikto) | Requiere la app desplegada en un entorno accesible externamente. El Learner Lab no lo garantiza. |
| Kubernetes | Opcional según las instrucciones. El Learner Lab tiene memoria limitada; Docker Compose es suficiente para demostrar la separación de servicios. |
| OAuth / SSO | El requisito pide autenticación simple; OAuth añadiría una dependencia externa innecesaria. |
| AWS SQS | RabbitMQ en contenedor cumple el mismo objetivo sin depender de credenciales rotativas del Learner Lab. |
| Multi-AZ en RDS | No disponible en el tier gratuito de AWS Academy para el Learner Lab. |
