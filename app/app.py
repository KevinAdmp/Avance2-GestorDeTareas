"""
Factory principal de Flask.
"""
import logging
import time
from flask import Flask, redirect, url_for
from .config import Config
from .extensions import db, login_manager
from .models import Usuario

logger = logging.getLogger(__name__)


def _init_db(app: Flask, retries: int = 10, delay: int = 3) -> None:
    """Intenta crear las tablas con reintentos por si la BD tarda en arrancar."""
    for attempt in range(1, retries + 1):
        try:
            with app.app_context():
                db.create_all()
            logger.info("Base de datos lista.")
            return
        except Exception as exc:  # pylint: disable=broad-except
            logger.warning(
                "BD no disponible (intento %d/%d): %s. Reintentando en %ds...",
                attempt, retries, exc, delay,
            )
            time.sleep(delay)
    logger.error("No se pudo conectar a la BD después de %d intentos.", retries)


def create_app() -> Flask:
    app = Flask(__name__)
    app.config.from_object(Config)

    # Inicializar extensiones
    db.init_app(app)
    login_manager.init_app(app)

    @login_manager.user_loader
    def load_user(user_id):
        return db.session.get(Usuario, int(user_id))

    # Registrar blueprints
    from .routes.health   import bp as health_bp
    from .routes.auth     import bp as auth_bp
    from .routes.tableros import bp as tableros_bp
    from .routes.tarjetas import bp as tarjetas_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(tableros_bp)
    app.register_blueprint(tarjetas_bp)

    # Ruta raíz
    @app.route("/")
    def index():
        return redirect(url_for("tableros.index"))

    # Crear tablas con reintentos (la BD puede tardar en estar lista)
    _init_db(app)

    return app
