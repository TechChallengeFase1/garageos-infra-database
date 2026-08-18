# ─── Quadro de avisos entre os repositorios ───────────────────────────────────
#
# Os 4 repos tem states Terraform separados e nao enxergam as variaveis uns dos
# outros. O SSM Parameter Store resolve isso: o bootstrap publica aqui os IDs
# que criou, e os outros repos leem com o data source `aws_ssm_parameter`.
#
# Exemplo de consumo no garageos-infra-k8s:
#
#   data "aws_ssm_parameter" "private_subnets" {
#     name = "/garageos/vpc/private-subnet-ids"
#   }
#   locals {
#     private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnets.value)
#   }
#
# O tier padrao do Parameter Store e gratuito - diferente do Secrets Manager,
# que cobra por segredo. Como nada aqui e sensivel (sao IDs, nao credenciais),
# o Parameter Store e a escolha certa.

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project}/vpc/id"
  type  = "String"
  value = aws_vpc.main.id
}

resource "aws_ssm_parameter" "vpc_cidr" {
  name  = "/${var.project}/vpc/cidr"
  type  = "String"
  value = aws_vpc.main.cidr_block
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/${var.project}/vpc/public-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.public[*].id)
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.project}/vpc/private-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)
}

resource "aws_ssm_parameter" "github_actions_role_arn" {
  name  = "/${var.project}/iam/github-actions-role-arn"
  type  = "String"
  value = aws_iam_role.github_actions.arn
}

resource "aws_ssm_parameter" "state_bucket" {
  name  = "/${var.project}/terraform/state-bucket"
  type  = "String"
  value = aws_s3_bucket.tfstate.id
}
