# ─── Senha do banco ───────────────────────────────────────────────────────────
#
# A senha nunca e escrita por uma pessoa nem versionada. O Terraform sorteia,
# usa na criacao do RDS e guarda no Secrets Manager. Ninguem precisa conhece-la
# para o sistema funcionar.
#
# AVISO IMPORTANTE: apesar disso, a senha em texto puro FICA no state do
# Terraform. E por isso que o state mora num bucket S3 privado e criptografado,
# e que o .gitignore deste repositorio bloqueia *.tfstate. Nao existe recurso
# no Terraform que evite isso - a unica defesa e proteger o state.

resource "random_password" "master" {
  length = 32

  # O RDS rejeita "/", '"', "@" e espaco na senha do master, e "@" tambem
  # quebraria a connection string do Npgsql. Por isso o conjunto de simbolos e
  # declarado a mao em vez de usar o padrao.
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?."
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${local.name}/rds/master"
  description = "Credenciais do RDS PostgreSQL do GarageOS (${local.env})"

  # Sem periodo de recuperacao. O padrao da AWS e 30 dias: o segredo apagado
  # entra em "scheduled for deletion" e o NOME fica reservado, entao um
  # `terraform destroy` seguido de `apply` falha com "already scheduled for
  # deletion" e o ambiente so volta um mes depois.
  #
  # Aqui a infraestrutura e destruida e recriada a cada janela de trabalho para
  # economizar credito, entao a recuperacao e abrida mao conscientemente.
  # Em producao real este valor seria 7 ou 30.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  # Guardado como JSON com todos os campos, e nao so a senha, para que quem
  # consome nao precise remontar nada. A `connectionString` ja vem no formato
  # do Npgsql, pronta para a API .NET e para a Lambda de autenticacao.
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name

    connectionString = join(";", [
      "Host=${aws_db_instance.main.address}",
      "Port=${aws_db_instance.main.port}",
      "Database=${var.db_name}",
      "Username=${var.db_username}",
      "Password=${random_password.master.result}",
      # O RDS aceita TLS por padrao. "Trust Server Certificate" evita ter de
      # embarcar a CA da Amazon na imagem da aplicacao; a conexao segue
      # criptografada, sem validacao da cadeia.
      "SSL Mode=Require",
      "Trust Server Certificate=true",
    ])
  })
}
