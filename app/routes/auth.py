"""
Blueprint de autenticación: registro e inicio de sesión.
"""
from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_user, logout_user, login_required, current_user
from ..extensions import db
from ..models import Usuario

bp = Blueprint("auth", __name__, url_prefix="/auth")


@bp.route("/registro", methods=["GET", "POST"])
def registro():
    if current_user.is_authenticated:
        return redirect(url_for("tableros.index"))

    if request.method == "POST":
        nombre   = request.form.get("nombre", "").strip()
        email    = request.form.get("email", "").strip().lower()
        password = request.form.get("password", "")
        confirma = request.form.get("confirma", "")

        if not nombre or not email or not password:
            flash("Todos los campos son obligatorios.", "danger")
        elif password != confirma:
            flash("Las contraseñas no coinciden.", "danger")
        elif len(password) < 8:
            flash("La contraseña debe tener al menos 8 caracteres.", "danger")
        elif Usuario.query.filter_by(email=email).first():
            flash("Ya existe una cuenta con ese correo.", "danger")
        else:
            usuario = Usuario(nombre=nombre, email=email)
            usuario.set_password(password)
            db.session.add(usuario)
            db.session.commit()
            login_user(usuario)
            flash("Cuenta creada exitosamente.", "success")
            return redirect(url_for("tableros.index"))

    return render_template("auth/registro.html")


@bp.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated:
        return redirect(url_for("tableros.index"))

    if request.method == "POST":
        email    = request.form.get("email", "").strip().lower()
        password = request.form.get("password", "")
        usuario  = Usuario.query.filter_by(email=email).first()

        if usuario and usuario.check_password(password):
            login_user(usuario)
            next_page = request.args.get("next")
            return redirect(next_page or url_for("tableros.index"))
        else:
            flash("Correo o contraseña incorrectos.", "danger")

    return render_template("auth/login.html")


@bp.route("/logout")
@login_required
def logout():
    logout_user()
    flash("Sesión cerrada.", "info")
    return redirect(url_for("auth.login"))
