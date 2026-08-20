# ─── Quem pode falar com o banco ──────────────────────────────────────────────
#
# PROBLEMA DE ORDEM: o requisito e "somente as origens necessarias tem acesso
# ao PostgreSQL", e a origem principal sao os nos do EKS - que ainda nao
# existem, porque este repositorio vem ANTES do garageos-infra-k8s.
#
# Liberar por faixa de IP resolveria e estaria errado: os nos escalam pelo HPA,
# trocam de IP, e a regra viraria uma faixa larga demais.
#
# SOLUCAO: dois Security Groups.
#
#   garageos-<env>-rds-client   um "cracha" vazio, sem regra de entrada
#   garageos-<env>-rds          o SG do banco, que aceita 5432 SO de quem
#                               estiver com o cracha
#
# O ID do cracha e publicado no SSM. Depois, o infra-k8s anexa esse SG aos nos
# e a Lambda anexa a si mesma. Ninguem precisa saber IP de ninguem, e a
# dependencia entre os repositorios continua apontando numa direcao so.

resource "aws_security_group" "rds_client" {
  name        = "${local.name}-rds-client"
  description = "Cracha de acesso ao RDS. Anexe a quem precisa falar com o banco."
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name}-rds-client"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "SG do RDS PostgreSQL. Entrada apenas de quem tem o cracha."
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name}-rds"
  }
}

# A unica porta de entrada do banco, e so para quem carrega o cracha.
# `referenced_security_group_id` continua valendo quando os nos escalam e
# trocam de IP - e por isso que nao ha nenhum CIDR aqui.
resource "aws_vpc_security_group_ingress_rule" "postgres_do_cliente" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.rds_client.id

  description = "PostgreSQL vindo de quem tem o cracha de cliente"
  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
}

# Caminho de saida do cliente ate o banco.
# Necessario porque o Terraform nao mantem a regra de egress permissiva que a
# AWS cria por padrao: um SG criado por `aws_security_group` sem egress
# declarado fica sem nenhuma saida.
resource "aws_vpc_security_group_egress_rule" "cliente_para_postgres" {
  security_group_id            = aws_security_group.rds_client.id
  referenced_security_group_id = aws_security_group.rds.id

  description = "Saida para o PostgreSQL"
  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
}

# O SG do banco nao tem regra de saida de proposito: um banco de dados responde
# conexoes, nunca inicia.
