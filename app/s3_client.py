"""
Cliente S3 — sube y genera URLs prefirmadas para archivos adjuntos.
"""
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

S3_BUCKET = os.environ.get("S3_BUCKET", "")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")


def _cliente():
    return boto3.client(
        "s3",
        region_name=AWS_REGION,
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY"),
        aws_session_token=os.environ.get("AWS_SESSION_TOKEN"),
    )


def subir_archivo(file_obj, clave: str) -> bool:
    """Sube un objeto de archivo a S3. Devuelve True si tuvo éxito."""
    try:
        _cliente().upload_fileobj(file_obj, S3_BUCKET, clave)
        logger.info("Archivo subido a S3: %s", clave)
        return True
    except ClientError as exc:
        logger.error("Error subiendo a S3: %s", exc)
        return False


def url_prefirmada(clave: str, expiracion: int = 3600):
    """Genera una URL prefirmada para descargar un objeto de S3."""
    try:
        url = _cliente().generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": clave},
            ExpiresIn=expiracion,
        )
        return url
    except ClientError as exc:
        logger.error("Error generando URL prefirmada: %s", exc)
        return None
