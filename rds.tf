# ─── DB Subnet Group ──────────────────────────────────────────────────────────
#
# Diz ao RDS em quais subnets ele pode se instalar. Exige no minimo 2 AZs,
# mesmo com `multi_az = false` - a AWS quer o destino do failover disponivel
# desde o inicio. Sao as subnets PRIVADAS: o banco nao tem rota para a
# internet, e nao precisa de nenhuma.

resource "aws_db_subnet_group" "main" {
  name        = "${local.name}-rds"
  description = "Subnets privadas onde o RDS do GarageOS pode viver"
  subnet_ids  = local.private_subnet_ids

  tags = {
    Name = "${local.name}-rds"
  }
}

# ─── A instancia ──────────────────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "${local.name}-postgres"

  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.db_instance_class

  # gp2, e nao gp3, porque o free tier cobre "General Purpose (SSD) gp2".
  # A diferenca de desempenho e irrelevante nesta carga.
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Sem endereco publico. O acesso vem de dentro da VPC, por quem tem o cracha.
  publicly_accessible = false

  # Multi-AZ dobraria o custo e sairia do free tier. Alta disponibilidade real
  # exigiria ligar - registrado como decisao consciente no README.
  multi_az = false

  backup_retention_period    = var.backup_retention_days
  auto_minor_version_upgrade = true
  apply_immediately          = true

  # Ambiente descartavel: o par abaixo permite `terraform destroy` sem
  # intervencao manual. Em producao seria o oposto - deletion_protection
  # ligada e snapshot final obrigatorio.
  skip_final_snapshot = true
  deletion_protection = false

  # Performance Insights e Enhanced Monitoring saem do free tier. O
  # monitoramento do projeto e feito pelo New Relic.
  performance_insights_enabled = false

  tags = {
    Name = "${local.name}-postgres"
  }
}
