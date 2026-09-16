"""
Blueprint de tableros: CRUD de tableros del usuario autenticado.
"""
from flask import Blueprint, render_template, redirect, url_for, flash, request, abort
from flask_login import login_required, current_user
from ..extensions import db
from ..models import Tablero

bp = Blueprint("tableros", __name__, url_prefix="/tableros")


@bp.route("/")
@login_required
def index():
    tableros = Tablero.query.filter_by(propietario_id=current_user.id)\
                            .order_by(Tablero.creado_en.desc()).all()
    return render_template("tableros/index.html", tableros=tableros)


@bp.route("/nuevo", methods=["GET", "POST"])
@login_required
def nuevo():
    if request.method == "POST":
        nombre      = request.form.get("nombre", "").strip()
        descripcion = request.form.get("descripcion", "").strip()

        if not nombre:
            flash("El nombre del tablero es obligatorio.", "danger")
        else:
            tablero = Tablero(
                nombre=nombre,
                descripcion=descripcion,
                propietario_id=current_user.id,
            )
            db.session.add(tablero)
            db.session.commit()
            flash("Tablero creado.", "success")
            return redirect(url_for("tableros.detalle", tablero_id=tablero.id))

    return render_template("tableros/nuevo.html")


@bp.route("/<int:tablero_id>")
@login_required
def detalle(tablero_id: int):
    tablero = Tablero.query.get_or_404(tablero_id)
    if tablero.propietario_id != current_user.id:
        abort(403)
    return render_template("tableros/detalle.html", tablero=tablero)


@bp.route("/<int:tablero_id>/eliminar", methods=["POST"])
@login_required
def eliminar(tablero_id: int):
    tablero = Tablero.query.get_or_404(tablero_id)
    if tablero.propietario_id != current_user.id:
        abort(403)
    db.session.delete(tablero)
    db.session.commit()
    flash("Tablero eliminado.", "info")
    return redirect(url_for("tableros.index"))
