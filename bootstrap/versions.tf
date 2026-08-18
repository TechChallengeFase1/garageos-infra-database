terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # ATENCAO - ovo e galinha do state remoto.
  #
  # Este bloco fica comentado no PRIMEIRO apply, porque o bucket que ele
  # referencia ainda nao existe - e quem cria o bucket e este mesmo Terraform.
  #
  # Depois do primeiro `terraform apply`:
  #   1. descomente o bloco abaixo;
  #   2. troque <ACCOUNT_ID> pelo numero da conta (veja o output state_bucket);
  #   3. rode `terraform init -migrate-state` e responda "yes";
  #   4. apague o terraform.tfstate local.
  #
  # backend "s3" {
  #   bucket       = "garageos-tfstate-<ACCOUNT_ID>"
  #   key          = "bootstrap/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.aws_region

  # Aplicadas automaticamente em todo recurso que suporta tags. Facilita
  # rastrear custo por projeto no Cost Explorer e limpar recursos orfaos.
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Source    = "garageos-infra-database/bootstrap"
    }
  }
}
