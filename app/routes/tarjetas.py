"""
Blueprint de tarjetas: CRUD de tareas dentro de un tablero.
Publica en RabbitMQ al crear una tarjeta con fecha límite.
Sube archivos adjuntos a S3.
"""
import uuid
from datetime import datetime
from flask import (Blueprint, render_template, redirect, url_for,
                   flash, request, abort)
from flask_login import login_required, current_user
from ..extensions import db
from ..models import Tablero, Tarjeta, Asignacion, Usuario
from ..queue_client import publicar_recordatorio
from ..s3_client import subir_archivo, url_prefirmada

bp = Blueprint("tarjetas", __name__, url_prefix="/tableros/<int:tablero_id>/tarjetas")


def _verificar_tablero(tablero_id: int) -> Tablero:
    tablero = Tablero.query.get_or_404(tablero_id)
    if tablero.propietario_id != current_user.id:
        abort(403)
    return tablero


@bp.route("/nueva", methods=["GET", "POST"])
@login_required
def nueva(tablero_id: int):
    tablero = _verificar_tablero(tablero_id)
    usuarios = Usuario.query.order_by(Usuario.nombre).all()

    if request.method == "POST":
        titulo       = request.form.get("titulo", "").strip()
        descripcion  = request.form.get("descripcion", "").strip()
        estado       = request.form.get("estado", "pendiente")
        prioridad    = request.form.get("prioridad", "media")
        fecha_str    = request.form.get("fecha_limite", "")
        asignados_ids = request.form.getlist("asignados")

        if not titulo:
            flash("El título es obligatorio.", "danger")
            return render_template("tarjetas/nueva.html", tablero=tablero,
                                   usuarios=usuarios)

        fecha_limite = None
        if fecha_str:
            try:
                fecha_limite = datetime.strptime(fecha_str, "%Y-%m-%dT%H:%M")
            except ValueError:
                flash("Formato de fecha inválido.", "danger")
                return render_template("tarjetas/nueva.html", tablero=tablero,
                                       usuarios=usuarios)

        # Subir adjunto a S3 si existe
        archivo_s3 = None
        archivo = request.files.get("adjunto")
        if archivo and archivo.filename:
            extension = archivo.filename.rsplit(".", 1)[-1].lower()
            clave = f"adjuntos/{uuid.uuid4().hex}.{extension}"
            if subir_archivo(archivo, clave):
                archivo_s3 = clave
            else:
                flash("No se pudo subir el adjunto a S3.", "warning")

        tarjeta = Tarjeta(
            titulo=titulo,
            descripcion=descripcion,
            estado=estado,
            prioridad=prioridad,
            fecha_limite=fecha_limite,
            archivo_s3=archivo_s3,
            tablero_id=tablero.id,
        )
        db.session.add(tarjeta)
        db.session.flush()  # obtener tarjeta.id antes del commit

        # Asignaciones
        emails_asignados = []
        for uid in asignados_ids:
            try:
                u = Usuario.query.get(int(uid))
                if u:
                    db.session.add(Asignacion(tarjeta_id=tarjeta.id, usuario_id=u.id))
                    emails_asignados.append(u.email)
            except (ValueError, TypeError):
                pass

        db.session.commit()

        # Publicar en RabbitMQ para que el worker envíe el recordatorio
        if fecha_limite:
            publicar_recordatorio(
                tarjeta_id=tarjeta.id,
                titulo=tarjeta.titulo,
                fecha_limite=fecha_limite.isoformat(),
                usuarios=emails_asignados,
            )

        flash("Tarjeta creada.", "success")
        return redirect(url_for("tableros.detalle", tablero_id=tablero.id))

    return render_template("tarjetas/nueva.html", tablero=tablero, usuarios=usuarios)


@bp.route("/<int:tarjeta_id>")
@login_required
def detalle(tablero_id: int, tarjeta_id: int):
    tablero = _verificar_tablero(tablero_id)
    tarjeta = Tarjeta.query.get_or_404(tarjeta_id)
    if tarjeta.tablero_id != tablero.id:
        abort(404)

    url_adjunto = None
    if tarjeta.archivo_s3:
        url_adjunto = url_prefirmada(tarjeta.archivo_s3)

    return render_template("tarjetas/detalle.html",
                           tablero=tablero, tarjeta=tarjeta,
                           url_adjunto=url_adjunto)


@bp.route("/<int:tarjeta_id>/editar", methods=["GET", "POST"])
@login_required
def editar(tablero_id: int, tarjeta_id: int):
    tablero = _verificar_tablero(tablero_id)
    tarjeta = Tarjeta.query.get_or_404(tarjeta_id)
    if tarjeta.tablero_id != tablero.id:
        abort(404)

    usuarios = Usuario.query.order_by(Usuario.nombre).all()

    if request.method == "POST":
        tarjeta.titulo      = request.form.get("titulo", tarjeta.titulo).strip()
        tarjeta.descripcion = request.form.get("descripcion", "").strip()
        tarjeta.estado      = request.form.get("estado", tarjeta.estado)
        tarjeta.prioridad   = request.form.get("prioridad", tarjeta.prioridad)
        fecha_str           = request.form.get("fecha_limite", "")

        if fecha_str:
            try:
                tarjeta.fecha_limite = datetime.strptime(fecha_str, "%Y-%m-%dT%H:%M")
            except ValueError:
                flash("Formato de fecha inválido.", "danger")

        db.session.commit()
        flash("Tarjeta actualizada.", "success")
        return redirect(url_for("tarjetas.detalle",
                                tablero_id=tablero.id, tarjeta_id=tarjeta.id))

    return render_template("tarjetas/editar.html",
                           tablero=tablero, tarjeta=tarjeta, usuarios=usuarios)


@bp.route("/<int:tarjeta_id>/eliminar", methods=["POST"])
@login_required
def eliminar(tablero_id: int, tarjeta_id: int):
    tablero = _verificar_tablero(tablero_id)
    tarjeta = Tarjeta.query.get_or_404(tarjeta_id)
    if tarjeta.tablero_id != tablero.id:
        abort(404)

    db.session.delete(tarjeta)
    db.session.commit()
    flash("Tarjeta eliminada.", "info")
    return redirect(url_for("tableros.detalle", tablero_id=tablero.id))
