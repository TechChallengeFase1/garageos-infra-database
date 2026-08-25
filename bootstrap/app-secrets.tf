# ─── Segredos compartilhados da aplicacao ────────────────────────────────────
#
# POR QUE AQUI, E NAO NO REPO DO BANCO:
#
# A JWT_SECRET_KEY e usada por DOIS componentes - a Lambda de autenticacao
# ASSINA o token, e a API .NET o VALIDA. Se as duas divergirem, a API rejeita
# silenciosamente todo token emitido pela Lambda: sem erro claro, sem log util,
# so 401 em tudo.
#
# Guardar isso no garageos-infra-database criaria um acoplamento absurdo -
# destruir o banco invalidaria todos os tokens em circulacao. Pela regra do
# projeto ("com que frequencia isso muda?"), e fundacao compartilhada: muda
# raramente e serve varios repositorios. Logo, bootstrap.
#
# Nada aqui e escrito por uma pessoa nem versionado. O Terraform sorteia, o
# Secrets Manager guarda, e a pipeline le na hora do deploy.

resource "random_password" "jwt_secret" {
  # 64 caracteres. HS256 exige no minimo 256 bits (32 bytes); o dobro nao
  # custa nada e evita qualquer discussao sobre forca da chave.
  length = 64

  # Sem simbolos de proposito. Esta chave atravessa variavel de ambiente,
  # Secret do Kubernetes e possivelmente linha de comando - alfanumerico
  # elimina toda uma classe de bug de escaping, sem perda real de entropia
  # (62^64 continua sendo um numero absurdo).
  special = false
}

resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?."
}

resource "aws_secretsmanager_secret" "app" {
  name        = "${var.project}/app/secrets"
  description = "Segredos compartilhados entre a API .NET e a Lambda de autenticacao"

  # Mesmo motivo do segredo do RDS: sem janela de recuperacao, o nome nao fica
  # reservado por 30 dias e um destroy/apply consegue recriar na hora.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    # Consumidos pela API como Jwt__SecretKey e Admin__Password.
    jwtSecretKey  = random_password.jwt_secret.result
    adminPassword = random_password.admin_password.result

    # Nao sao segredo, mas viajam junto para que a Lambda e a API leiam issuer
    # e audience da MESMA fonte. Divergencia aqui quebra a validacao do token
    # do mesmo jeito que uma chave diferente.
    jwtIssuer   = "GarageOS.Api"
    jwtAudience = "GarageOS.Client"
  })
}

# Ponteiro para o segredo. A pipeline do garageos-app e a da Lambda leem daqui
# o ARN, e so entao buscam o conteudo no Secrets Manager.
resource "aws_ssm_parameter" "app_secret_arn" {
  name        = "/${var.project}/app/secret-arn"
  description = "ARN do segredo com JWT e credenciais de admin da aplicacao"
  type        = "String"
  value       = aws_secretsmanager_secret.app.arn
}
