# Valores que voce vai precisar copiar a mao depois do primeiro apply:
#   - state_bucket        -> para o bloco backend "s3" (em versions.tf)
#   - github_actions_role -> para o role-to-assume dos workflows dos 4 repos

output "state_bucket" {
  description = "Bucket S3 onde vivem os states dos 4 repositorios"
  value       = aws_s3_bucket.tfstate.id
}

output "github_actions_role_arn" {
  description = "ARN da role assumida pelos workflows via OIDC (role-to-assume)"
  value       = aws_iam_role.github_actions.arn
}

output "vpc_id" {
  description = "ID da VPC onde EKS e RDS serao criados"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Subnets publicas (nos do EKS e Load Balancers)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Subnets privadas (RDS e Lambda)"
  value       = aws_subnet.private[*].id
}

output "backend_config" {
  description = "Bloco backend pronto para colar em versions.tf apos o primeiro apply"
  value       = <<-EOT
    backend "s3" {
      bucket       = "${aws_s3_bucket.tfstate.id}"
      key          = "bootstrap/terraform.tfstate"
      region       = "${var.aws_region}"
      encrypt      = true
      use_lockfile = true
    }
  EOT
}
