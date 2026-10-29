output "ambiente" {
  description = "Ambiente derivado do workspace do Terraform"
  value       = local.env
}

output "rds_client_security_group_id" {
  description = "SG a ser anexado por quem precisa acessar um banco (nos do EKS, Lambda)"
  value       = aws_security_group.rds_client.id
}
