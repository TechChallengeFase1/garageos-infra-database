terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Diferente de bootstrap/, aqui o backend ja nasce configurado: o bucket foi
  # criado la e existe desde o inicio. Nao ha manobra de migracao de state.
  #
  # Workspaces: o `default` nao e usado. Cada ambiente tem o seu, e o S3
  # separa os states automaticamente:
  #   env:/homolog/database/terraform.tfstate
  #   env:/producao/database/terraform.tfstate
  backend "s3" {
    bucket       = "garageos-tfstate-266380777968"
    key          = "database/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = local.env
      ManagedBy   = "terraform"
      Source      = "garageos-infra-database"
    }
  }
}

locals {
  # O workspace e a fonte da verdade do ambiente. `default` cai em producao
  # para que um apply distraido da maquina local nao crie um ambiente fantasma
  # com nome errado.
  env  = terraform.workspace == "default" ? "producao" : terraform.workspace
  name = "${var.project}-${local.env}"
}
