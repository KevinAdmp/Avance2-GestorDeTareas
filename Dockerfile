# ── Imagen base: versión fija, slim para reducir superficie de ataque ────────
FROM python:3.12.4-slim

# Metadatos
LABEL maintainer="kevin.morales@tecmilenio.mx"
LABEL description="API Flask — Gestor de Tareas Colaborativo"

# ── Variables de entorno de build ────────────────────────────────────────────
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# ── Crear usuario sin privilegios (no root) ──────────────────────────────────
RUN groupadd --system appgroup && \
    useradd  --system --gid appgroup --no-create-home appuser

# ── Instalar dependencias del sistema mínimas ────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libpq5 \
        curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ── Directorio de trabajo ────────────────────────────────────────────────────
WORKDIR /srv

# ── Instalar dependencias Python ─────────────────────────────────────────────
COPY app/requirements.txt /srv/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# ── Copiar código fuente ─────────────────────────────────────────────────────
# La carpeta app/ del repo queda en /srv/app/ dentro del contenedor,
# y wsgi.py queda en /srv/wsgi.py → "from app import create_app" funciona.
COPY app/ /srv/app/
# Copiar wsgi.py un nivel arriba del paquete app/
COPY app/wsgi.py /srv/wsgi.py

# ── Permisos: el usuario appuser solo necesita leer el código ────────────────
RUN chown -R appuser:appgroup /srv

# ── Cambiar a usuario sin privilegios ────────────────────────────────────────
USER appuser

# ── Exponer puerto ────────────────────────────────────────────────────────────
EXPOSE 5000

# ── HEALTHCHECK — usado por Docker y el pipeline ─────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:5000/salud || exit 1

# ── Punto de entrada: Gunicorn en modo producción ────────────────────────────
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", \
     "--timeout", "60", "--access-logfile", "-", "wsgi:application"]
