# Gestor de Tareas Colaborativo

Aplicación web para gestionar tableros, tarjetas, asignaciones y fechas límite.
Construida con Flask (Python), contenedores Docker y servicios de AWS Academy.

## ¿Qué hace?

- Registro e inicio de sesión de usuarios
- Creación de **tableros** (tipo Kanban)
- Creación de **tarjetas** (tareas) con título, descripción, estado, prioridad, fecha límite y archivo adjunto
- **Asignación** de tarjetas a usuarios
- **Recordatorios automáticos** vía cola de mensajes RabbitMQ (pieza técnica distintiva del Tema 5)
- Adjuntos almacenados en **S3** con URL prefirmada para descarga segura

## Arquitectura de servicios

| Servicio | Tecnología | Puerto |
|---|---|---|
| API Flask | Python 3.12 + Gunicorn | 5001 |
| Worker de recordatorios | Python 3.12 + pika | — |
| Cola de mensajes | RabbitMQ 3.13 | 5672 / 15672 |

Los tres servicios corren en contenedores separados orquestados con `docker-compose`.
La base de datos y el bucket viven en AWS Academy (no en contenedores locales).

## Cómo levantar la aplicación

### 1. Prerrequisitos

- Docker 24+ y Docker Compose v2
- Cuenta de AWS Academy con un bucket S3 y una instancia RDS PostgreSQL activos

### 2. Configurar variables de entorno

```bash
cp .env.example .env
# Editar .env con tus valores reales de AWS Academy
```

### 3. Levantar los contenedores

```bash
docker compose up --build -d
```

### 4. Verificar que todo está vivo

```bash
curl http://localhost:5000/salud
# → {"estado": "ok", "servicio": "gestor-tareas-api"}

docker compose ps
# api, worker y rabbitmq deben aparecer como "healthy" o "running"
```

### 5. Acceder a la aplicación

- App: [http://localhost:5000](http://localhost:5001)
- Consola RabbitMQ: [http://localhost:15672](http://localhost:15672) (guest / guest)

### 6. Detener

```bash
docker compose down
```

## Flujo de un recordatorio

```
Usuario crea tarjeta con fecha límite
        │
        ▼
API Flask  →  publica JSON en cola 'recordatorios' (RabbitMQ)
                        │
                        ▼
               Worker (contenedor separado)
               consume el mensaje y escribe el aviso en log
```

Este desacoplamiento es la **pieza técnica distintiva** del Tema 5:
la creación de la tarea y el envío del recordatorio son procesos completamente independientes.

## Servicios de AWS utilizados

| Servicio | Uso |
|---|---|
| **S3** | Almacenamiento de archivos adjuntos a tarjetas. Bucket privado, cifrado KMS, acceso público bloqueado. |
| **RDS PostgreSQL** | Base de datos de usuarios, tableros, tarjetas y asignaciones. Sin acceso público, cifrada en reposo. |

## Endpoint de salud

```
GET /salud
→ 200 OK  {"estado": "ok", "servicio": "gestor-tareas-api"}
```

## Estructura del repositorio

```
.
├── app/                        # Código fuente de la API Flask
│   ├── routes/                 # Blueprints: auth, tableros, tarjetas, health
│   ├── templates/              # HTML (Jinja2 + Bootstrap 5)
│   ├── worker/                 # Worker RabbitMQ (contenedor separado)
│   ├── models.py               # Modelos SQLAlchemy
│   ├── queue_client.py         # Publicador RabbitMQ
│   └── s3_client.py            # Cliente S3
├── infra/                      # Infraestructura como código (Terraform)
├── pipeline/                   # Scripts DevSecOps + Jenkinsfile
├── reportes/                   # Salidas del pipeline (corridas roja y verde, SBOM)
├── docs/                       # Documentación
├── Dockerfile                  # API (endurecido)
├── Dockerfile.worker           # Worker (endurecido)
└── docker-compose.yml          # Orquestación de los 3 servicios
```
