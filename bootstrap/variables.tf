variable "aws_region" {
  description = "Regiao onde toda a infraestrutura do GarageOS vive. us-east-1 e a mais barata."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo usado no nome dos recursos"
  type        = string
  default     = "garageos"
}

variable "github_org" {
  description = "Organizacao do GitHub dona dos 4 repositorios"
  type        = string
  default     = "TechChallengeFase1"
}

variable "github_repos" {
  description = <<-EOT
    Repositorios autorizados a assumir a role via OIDC.
    Listados um a um de proposito: um curinga como "TechChallengeFase1/*"
    permitiria que qualquer repo novo da organizacao mexesse nesta conta.
  EOT
  type        = list(string)
  default = [
    "garageos-app",
    "garageos-infra-database",
    "garageos-infra-k8s",
    "garageos-lambda-auth",
  ]
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC (65 mil enderecos)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = <<-EOT
    Availability Zones usadas. Minimo de 2 nao e recomendacao, e exigencia:
    o EKS recusa criar cluster com uma AZ so, e o DB Subnet Group do RDS
    tambem.
  EOT
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
