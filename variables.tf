variable "aws_region" {
  description = "Regiao. Precisa ser a mesma do bootstrap - a VPC nao atravessa regioes."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo dos recursos"
  type        = string
  default     = "garageos"
}

variable "db_name" {
  description = "Nome do banco criado dentro da instancia"
  type        = string
  default     = "garageos"
}

variable "db_username" {
  description = <<-EOT
    Usuario master. Nao pode ser "postgres", "admin", "rdsadmin" nem outras
    palavras reservadas pelo RDS - a criacao falha.
  EOT
  type        = string
  default     = "garageos"
}

variable "db_instance_class" {
  description = <<-EOT
    Classe da instancia. db.t4g.micro e elegivel ao free tier (750h/mes nos
    primeiros 12 meses da conta, uma instancia por vez). Rodar homolog e
    producao ao mesmo tempo passa do limite e comeca a cobrar.
  EOT
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Armazenamento em GB. 20 e o minimo do RDS e o teto do free tier."
  type        = number
  default     = 20
}

variable "backup_retention_days" {
  description = <<-EOT
    Dias de retencao de backup automatico. 0 desliga.
    Em producao de verdade isso jamais seria 0 - aqui e ambiente descartavel,
    recriado do zero a cada demonstracao.
  EOT
  type        = number
  default     = 1
}

variable "postgres_version" {
  description = <<-EOT
    Versao major do PostgreSQL. So o major de proposito: a AWS escolhe o minor
    mais recente e aplica correcoes sozinha, sem gerar diff no Terraform.
  EOT
  type        = string
  default     = "16"
}
