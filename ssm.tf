# ─── O que este repositorio publica para os outros ────────────────────────────
#
# So o ID do cracha. Os parametros /garageos/<env>/rds/* (endpoint, porta,
# dbname e secret-arn) eram do RDS do monolito e sairam com ele: cada servico
# publica os do proprio banco em /garageos/<env>/services/<servico>/*.

resource "aws_ssm_parameter" "rds_client_sg_id" {
  name        = "/${var.project}/${local.env}/rds/client-security-group-id"
  description = "Anexe este SG a qualquer recurso que precise falar com um RDS"
  type        = "String"
  value       = aws_security_group.rds_client.id
}
