terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Usado em app-secrets.tf para sortear a JWT_SECRET_KEY e a senha de admin.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State remoto no bucket criado por esta mesma raiz (ver s3-state.tf).
  #
  # Ovo e galinha: no PRIMEIRO apply este bloco ficou comentado, porque o bucket
  # que ele referencia ainda nao existia. Criado o bucket, o bloco foi
  # descomentado e o state local migrado com `terraform init -migrate-state`.
  #
  # O nome do bucket esta escrito a mao de proposito: blocos backend nao aceitam
  # variaveis nem interpolacao - sao lidos antes de o Terraform avaliar
  # qualquer expressao.
  backend "s3" {
    bucket       = "garageos-tfstate-266380777968"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
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
