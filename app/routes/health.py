"""
Endpoint /salud — responde si la aplicación está viva.
Usado por el pipeline y el HEALTHCHECK del contenedor.
"""
from flask import Blueprint, jsonify

bp = Blueprint("health", __name__)


@bp.route("/salud")
def salud():
    return jsonify({"estado": "ok", "servicio": "gestor-tareas-api"}), 200
