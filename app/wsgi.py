"""
Punto de entrada para Gunicorn.
Este archivo se copia a /srv/wsgi.py en el contenedor,
un nivel por encima del paquete app/ (/srv/app/),
para que 'from app import create_app' resuelva correctamente.
"""
from app.app import create_app

application = create_app()

if __name__ == "__main__":
    application.run(host="0.0.0.0", port=5000)
