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
