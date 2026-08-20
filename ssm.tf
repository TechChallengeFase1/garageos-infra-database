# ─── O que este repositorio publica para os outros ────────────────────────────
#
# Os caminhos levam o ambiente, porque homolog e producao tem bancos distintos:
#   /garageos/<env>/rds/endpoint
#
# Diferente da VPC, que e compartilhada e vive em /garageos/vpc/*.
#
# Nenhum valor aqui e sensivel - sao endereco, porta e nomes. A SENHA nao entra
# no Parameter Store: ela fica no Secrets Manager, e o que se publica aqui e
# apenas o ARN de onde busca-la.

resource "aws_ssm_parameter" "rds_endpoint" {
  name        = "/${var.project}/${local.env}/rds/endpoint"
  description = "Hostname do RDS PostgreSQL (sem a porta)"
  type        = "String"
  value       = aws_db_instance.main.address
}

resource "aws_ssm_parameter" "rds_port" {
  name  = "/${var.project}/${local.env}/rds/port"
  type  = "String"
  value = tostring(aws_db_instance.main.port)
}

resource "aws_ssm_parameter" "rds_dbname" {
  name  = "/${var.project}/${local.env}/rds/dbname"
  type  = "String"
  value = var.db_name
}

# O cracha. O garageos-infra-k8s le este ID e anexa o SG aos nos do cluster;
# a Lambda de autenticacao faz o mesmo. E o contrato de acesso ao banco.
resource "aws_ssm_parameter" "rds_client_sg_id" {
  name        = "/${var.project}/${local.env}/rds/client-security-group-id"
  description = "Anexe este SG a qualquer recurso que precise falar com o RDS"
  type        = "String"
  value       = aws_security_group.rds_client.id
}

# Ponteiro para o segredo, nunca o segredo.
resource "aws_ssm_parameter" "rds_secret_arn" {
  name        = "/${var.project}/${local.env}/rds/secret-arn"
  description = "ARN do segredo com usuario, senha e connection string"
  type        = "String"
  value       = aws_secretsmanager_secret.db.arn
}
