# ─── O que o bootstrap deixou no quadro de avisos ─────────────────────────────
#
# Este repositorio NAO cria rede. A VPC e as subnets vieram do bootstrap, e sao
# descobertas aqui pelo SSM Parameter Store.
#
# A alternativa seria `terraform_remote_state`, lendo o state do bootstrap
# direto do S3. O SSM foi preferido por dois motivos: nao exige permissao de
# leitura no state alheio (que traria junto TUDO que existe la, inclusive
# valores sensiveis), e o contrato fica explicito - o que e publicado e o que
# outros repos podem consumir.

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project}/vpc/id"
}

data "aws_ssm_parameter" "vpc_cidr" {
  name = "/${var.project}/vpc/cidr"
}

locals {
  vpc_id   = data.aws_ssm_parameter.vpc_id.value
  vpc_cidr = data.aws_ssm_parameter.vpc_cidr.value
}
