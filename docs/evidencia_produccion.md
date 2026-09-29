# Evidencia de Promoción a Producción
**Proyecto:** Gestor de Tareas Colaborativo — Tema 5  
**Autor:** Kevin Morales  
**Fecha:** 2026-09-28  
**Entrega:** Entrega Final del Reto — LSCA2314 · Periodo AD26

---

## Resumen del ciclo completo

| Paso | Ambiente | Estado |
|---|---|---|
| 1. Parche aplicado | QA (Mac local + RDS) | ✅ Completado |
| 2. Pipeline bloqueó el parche | QA | ✅ Completado — Bandit B301 CWE-502 |
| 3. Hallazgo clasificado | QA | ✅ Completado — docs/clasificacion_hallazgo.md |
| 4. Contención y prevención documentadas | QA | ✅ Completado — docs/respuesta_incidente.md |
| 5. Código remediado (pickle → json) | QA | ✅ Completado |
| 6. Pipeline en verde (6/6 etapas) | QA | ✅ Completado — reportes/pipeline_verde.txt |
| 7. Código promovido a Producción | EC2 Producción | ✅ Completado |

---

## Instancia de QA (EC2)

- **Instance ID:** `i-04b7e403ebf90aa44`
- **Nombre:** `gestor-tareas-qa`
- **IP pública:** `34.229.86.30`
- **Tipo:** t2.micro · us-east-1
- **URL health check:** `http://34.229.86.30:5001/salud` → HTTP 200 ✅
- **Contenedores:** `gestor_api`, `gestor_worker`, `gestor_rabbitmq`
- **BD:** `gestor-tareas-db.csey27ukhrwo.us-east-1.rds.amazonaws.com` (RDS AWS Academy)

---

## Instancia de Producción (EC2)

- **Instance ID:** `i-0c0ccca6659181ce1`
- **Nombre:** `gestor-tareas-produccion`
- **IP pública:** `98.84.159.9`
- **Tipo:** t2.micro · us-east-1
- **URL health check:** `http://98.84.159.9:5001/salud` → HTTP 200 ✅
- **Contenedores:** `gestor_api`, `gestor_worker`, `gestor_rabbitmq`
- **BD:** `gestor-tareas-db.csey27ukhrwo.us-east-1.rds.amazonaws.com` (misma RDS)

---

## Pasos para levantar la instancia de Producción en EC2

### 1. Crear la instancia EC2 en AWS Academy
- Ve a **EC2 → Launch Instance**
- AMI: **Amazon Linux 2023** (o Ubuntu 22.04)
- Instance type: `t2.micro`
- Key pair: usa el que ya tienes o crea uno nuevo
- Security Group: abre puertos **22** (SSH) y **5001** (HTTP app)
- Click **Launch**

### 2. Conectar por SSH e instalar Docker
```bash
ssh -i tu-key.pem ec2-user@[IP-EC2]

# Instalar Docker
sudo yum update -y
sudo yum install -y docker git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 3. Clonar el repositorio (con el código ya remediado)
```bash
git clone https://github.com/KevinAdmp/Avance2-GestorDeTareas.git
cd Avance2-GestorDeTareas
```

### 4. Crear el archivo .env en Producción
```bash
cat > .env << 'EOF'
SECRET_KEY=gestor-tareas-secret-key-lsca2314-ad26-kevin-morales
DB_HOST=gestor-tareas-db.csey27ukhrwo.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=gestortareas
DB_USER=postgres
DB_PASSWORD=KAMP#5387
AWS_REGION=us-east-1
S3_BUCKET=avancee2
AWS_ACCESS_KEY_ID=[TU_ACCESS_KEY]
AWS_SECRET_ACCESS_KEY=[TU_SECRET_KEY]
AWS_SESSION_TOKEN=[TU_SESSION_TOKEN]
RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/
TASK_QUEUE=recordatorios
EOF
```

### 5. Levantar los contenedores
```bash
docker-compose up --build -d
```

### 6. Verificar que la app responde
```bash
curl http://localhost:5001/salud
# Debe responder: {"estado": "ok", "servicio": "gestor-tareas-api"}
```

---

## Capturas de evidencia

### Captura 1 — Instancia EC2 de Producción en la consola AWS
> Mostrar: Instance ID, estado "Running", IP pública, región us-east-1

[INSERTAR CAPTURA]

### Captura 2 — SSH conectado a la instancia de Producción
> Mostrar: terminal conectado por SSH a la EC2, comando `docker ps` mostrando contenedores corriendo

[INSERTAR CAPTURA]

### Captura 3 — Health check desde Producción
> Mostrar: `curl http://localhost:5001/salud` devolviendo HTTP 200

[INSERTAR CAPTURA]

### Captura 4 — App funcionando en Producción (browser)
> Mostrar: la app accesible en `http://[IP-EC2]:5001` desde el navegador

[INSERTAR CAPTURA]

---

## Confirmación del ciclo QA → Producción

El código que se desplegó en Producción es **exactamente el mismo** que pasó el pipeline en verde:
- Commit de remediación: `pickle.loads()` → `json.loads()` en `app/worker/importar_plantilla_tarea.py`
- Pipeline verde: 6/6 etapas PASS (ver `reportes/pipeline_verde.txt`)
- El parche con la vulnerabilidad **nunca llegó a Producción** — fue bloqueado en QA por Bandit B301 (CWE-502)
