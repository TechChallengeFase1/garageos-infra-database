# ─── O cracha de acesso aos bancos ───────────────────────────────────────────
#
# Fase 4: este repositorio deixou de ter banco. Cada microsservico provisiona o
# proprio RDS na pasta infra/ do seu repositorio (ADR 0004 do garageos-app), e
# o RDS do monolito saiu daqui - inclusive porque o plano gratuito da conta
# permite no maximo 2 instancias RDS, exatamente as do OS e do Execucao.
#
# O que continua aqui e o "cracha": um Security Group vazio que o infra-k8s
# anexa aos nos do EKS. O SG do RDS de cada servico aceita a porta 5432 so de
# quem carrega o cracha. Ninguem precisa saber IP de ninguem, e a dependencia
# entre os repositorios continua apontando numa direcao so (ADR 0001).
#
# Ele mora aqui, e nao no repo de um servico, porque e anterior a todos eles:
# o cluster precisa do ID do cracha para criar os nos, e os bancos dos servicos
# precisam do mesmo ID para liberar a entrada.

resource "aws_security_group" "rds_client" {
  name        = "${local.name}-rds-client"
  description = "Cracha de acesso ao RDS. Anexe a quem precisa falar com o banco."
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name}-rds-client"
  }
}

# Saida do cliente ate qualquer banco da VPC.
# Antes apontava para o SG do unico RDS; agora cada servico tem o seu, entao a
# saida vai para a porta 5432 dentro da VPC. A entrada continua restrita no SG
# de cada banco, que so aceita quem carrega o cracha.
#
# Necessaria porque o Terraform nao mantem a regra de egress permissiva que a
# AWS cria por padrao: um SG criado por `aws_security_group` sem egress
# declarado fica sem nenhuma saida.
resource "aws_vpc_security_group_egress_rule" "cliente_para_postgres" {
  security_group_id = aws_security_group.rds_client.id
  cidr_ipv4         = local.vpc_cidr

  description = "Saida para os PostgreSQL da VPC"
  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
}
