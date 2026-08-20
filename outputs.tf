output "ambiente" {
  description = "Ambiente derivado do workspace do Terraform"
  value       = local.env
}

output "rds_endpoint" {
  description = "Hostname do RDS. Alcancavel apenas de dentro da VPC."
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "Porta do PostgreSQL"
  value       = aws_db_instance.main.port
}

output "rds_client_security_group_id" {
  description = "SG a ser anexado por quem precisa acessar o banco (nos do EKS, Lambda)"
  value       = aws_security_group.rds_client.id
}

output "secret_arn" {
  description = "ARN do segredo com as credenciais no Secrets Manager"
  value       = aws_secretsmanager_secret.db.arn
}

output "como_ler_a_senha" {
  description = "Comando para recuperar a connection string, quando necessario"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db.name} --query SecretString --output text"
}

# A senha em si nao vira output de proposito. Um output sensitive continua
# gravado em texto puro no state e aparece em `terraform output -json`, entao
# expo-lo so aumentaria a superficie sem necessidade: quem precisa da senha
# busca no Secrets Manager, com permissao propria e registro no CloudTrail.
