# ─── Bucket S3 do state remoto do Terraform ───────────────────────────────────
#
# Por que existe: o state guarda "o que ja criei e qual o ID de cada coisa".
# Enquanto ele vive no disco local, a pipeline nao consegue trabalhar - o runner
# do GitHub e descartavel e comeca sem arquivo nenhum, entao acharia que nada
# existe e tentaria criar tudo de novo.
#
# Um state por repo, isolados por prefixo dentro do mesmo bucket:
#   bootstrap/terraform.tfstate
#   database/terraform.tfstate
#   k8s/terraform.tfstate
#   lambda/terraform.tfstate
#
# O isolamento e o ponto: um `terraform destroy` no cluster nao consegue nem
# enxergar o banco.

data "aws_caller_identity" "current" {}

locals {
  # Nome de bucket S3 e GLOBAL, nao por conta - "garageos-tfstate" sozinho
  # provavelmente ja existe no mundo. O account id garante unicidade.
  state_bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.state_bucket_name

  # Protege contra `terraform destroy` acidental. Destruir este bucket significa
  # perder o registro de TODA a infraestrutura das outras raizes Terraform, que
  # continuariam existindo na AWS sem ninguem sabendo.
  #
  # Para desmontar o projeto de verdade no fim da fase: comente este bloco,
  # rode `terraform apply`, e so entao `terraform destroy`.
  lifecycle {
    prevent_destroy = true
  }
}

# Versionamento: permite voltar para uma versao anterior do state se ele
# corromper no meio de um apply interrompido. Nao e opcional.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# O state pode conter endpoints, IDs e ate segredos. Nunca publico.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# NOTA sobre o lock:
# A maioria dos tutoriais manda criar uma tabela DynamoDB para o lock de state.
# A partir do Terraform 1.10 existe lock nativo do S3 (`use_lockfile = true` no
# bloco backend), e o metodo por DynamoDB esta depreciado. Como o projeto usa
# Terraform 1.15+, a tabela foi dispensada: um recurso a menos para criar,
# pagar e destruir.
