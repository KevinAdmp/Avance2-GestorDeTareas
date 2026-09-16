"""
Modelos de base de datos.
Tablas: usuarios, tableros, tarjetas (tareas), asignaciones.
"""
from datetime import datetime, timezone
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from .extensions import db


class Usuario(UserMixin, db.Model):
    __tablename__ = "usuarios"

    id         = db.Column(db.Integer, primary_key=True)
    nombre     = db.Column(db.String(80), nullable=False)
    email      = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    creado_en  = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    # relaciones
    tableros   = db.relationship("Tablero", backref="propietario", lazy=True,
                                 foreign_keys="Tablero.propietario_id")
    asignaciones = db.relationship("Asignacion", backref="usuario", lazy=True)

    def set_password(self, password: str) -> None:
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)

    def __repr__(self) -> str:
        return f"<Usuario {self.email}>"


class Tablero(db.Model):
    __tablename__ = "tableros"

    id            = db.Column(db.Integer, primary_key=True)
    nombre        = db.Column(db.String(120), nullable=False)
    descripcion   = db.Column(db.Text, default="")
    propietario_id = db.Column(db.Integer, db.ForeignKey("usuarios.id"), nullable=False)
    creado_en     = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    tarjetas = db.relationship("Tarjeta", backref="tablero", lazy=True,
                               cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Tablero {self.nombre}>"


class Tarjeta(db.Model):
    __tablename__ = "tarjetas"

    id           = db.Column(db.Integer, primary_key=True)
    titulo       = db.Column(db.String(200), nullable=False)
    descripcion  = db.Column(db.Text, default="")
    estado       = db.Column(db.String(30), default="pendiente")   # pendiente | en_progreso | completada
    prioridad    = db.Column(db.String(20), default="media")        # baja | media | alta
    fecha_limite = db.Column(db.DateTime, nullable=True)
    archivo_s3   = db.Column(db.String(512), nullable=True)         # clave del objeto en S3
    tablero_id   = db.Column(db.Integer, db.ForeignKey("tableros.id"), nullable=False)
    creado_en    = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    asignaciones = db.relationship("Asignacion", backref="tarjeta", lazy=True,
                                   cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Tarjeta {self.titulo}>"


class Asignacion(db.Model):
    __tablename__ = "asignaciones"

    id          = db.Column(db.Integer, primary_key=True)
    tarjeta_id  = db.Column(db.Integer, db.ForeignKey("tarjetas.id"), nullable=False)
    usuario_id  = db.Column(db.Integer, db.ForeignKey("usuarios.id"), nullable=False)
    asignado_en = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        db.UniqueConstraint("tarjeta_id", "usuario_id", name="uq_asignacion"),
    )

    def __repr__(self) -> str:
        return f"<Asignacion tarjeta={self.tarjeta_id} usuario={self.usuario_id}>"
