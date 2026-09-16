"""
Configuración de la aplicación. Todas las credenciales vienen
de variables de entorno; nunca se escriben aquí directamente.
"""
import os


class Config:
    # Flask
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only-change-in-production")

    # Base de datos RDS (PostgreSQL)
    DB_HOST = os.environ.get("DB_HOST", "db")
    DB_PORT = os.environ.get("DB_PORT", "5432")
    DB_NAME = os.environ.get("DB_NAME", "gestortareas")
    DB_USER = os.environ.get("DB_USER", "postgres")
    DB_PASSWORD = os.environ.get("DB_PASSWORD", "GestorPass2024!")

    SQLALCHEMY_DATABASE_URI = (
        f"postgresql://{DB_USER}:{DB_PASSWORD}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "pool_recycle": 300,
        "connect_args": {
            "connect_timeout": 10,
        },
    }

    # AWS S3
    AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
    AWS_ACCESS_KEY_ID = os.environ.get("AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY", "")
    AWS_SESSION_TOKEN = os.environ.get("AWS_SESSION_TOKEN", "")
    S3_BUCKET = os.environ.get("S3_BUCKET", "")

    # RabbitMQ
    RABBITMQ_URL = os.environ.get("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
    TASK_QUEUE = os.environ.get("TASK_QUEUE", "recordatorios")
