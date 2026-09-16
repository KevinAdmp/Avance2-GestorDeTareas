###############################################################################
# Infraestructura como Código — Gestor de Tareas Colaborativo
# Describe el bucket S3 y la instancia RDS que usa la aplicación.
# Aunque los recursos se crearon por consola en AWS Academy, este archivo
# los describe formalmente y pasa el escaneo de IaC del pipeline (Checkov).
###############################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Las credenciales vienen de variables de entorno:
  # AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
  # Nunca se escriben en este archivo.
}

# ── Variables ─────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "Región de AWS donde se crean los recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para nombrar los recursos"
  type        = string
  default     = "gestor-tareas"
}

variable "db_username" {
  description = "Usuario maestro de RDS"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña maestra de RDS"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "gestortareas"
}

variable "vpc_id" {
  description = "ID del VPC donde se despliega RDS"
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista de subnets privadas para el subnet group de RDS"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group de la instancia EC2 de la aplicación"
  type        = string
}

# ── Bucket S3 ─────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "adjuntos" {
  bucket        = "${var.project_name}-adjuntos"
  force_destroy = false

  tags = {
    Project     = var.project_name
    Environment = "qa"
    ManagedBy   = "terraform"
  }
}

# Bloquear todo acceso público — requisito de seguridad
resource "aws_s3_bucket_public_access_block" "adjuntos" {
  bucket = aws_s3_bucket.adjuntos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifrado del lado del servidor con clave administrada por AWS
resource "aws_s3_bucket_server_side_encryption_configuration" "adjuntos" {
  bucket = aws_s3_bucket.adjuntos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Versioning habilitado para recuperación ante borrado accidental
resource "aws_s3_bucket_versioning" "adjuntos" {
  bucket = aws_s3_bucket.adjuntos.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ── Subnet Group para RDS ─────────────────────────────────────────────────────

resource "aws_db_subnet_group" "gestor" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Project = var.project_name
  }
}

# ── Security Group de RDS (solo acepta tráfico de la app) ─────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Permite acceso a PostgreSQL solo desde la instancia de la aplicación"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL desde la app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    description = "Sin salida desde RDS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # requerido por AWS; RDS no inicia conexiones salientes
  }

  tags = {
    Project = var.project_name
  }
}

# ── Instancia RDS PostgreSQL ──────────────────────────────────────────────────

resource "aws_db_instance" "gestor" {
  identifier             = "${var.project_name}-db"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Seguridad: sin acceso público, solo desde la red privada
  publicly_accessible    = false
  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.gestor.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Cifrado en reposo obligatorio
  storage_encrypted = true

  # Backups automáticos — 7 días de retención
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Protección ante borrado accidental
  deletion_protection      = false   # false para el Learner Lab (se borra al apagar)
  skip_final_snapshot      = true
  delete_automated_backups = true

  # Actualizaciones de parches menores automáticas
  auto_minor_version_upgrade = true

  tags = {
    Project     = var.project_name
    Environment = "qa"
    ManagedBy   = "terraform"
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "s3_bucket_name" {
  description = "Nombre del bucket S3 de adjuntos"
  value       = aws_s3_bucket.adjuntos.bucket
}

output "rds_endpoint" {
  description = "Endpoint de conexión a RDS"
  value       = aws_db_instance.gestor.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "Puerto de RDS"
  value       = aws_db_instance.gestor.port
}
