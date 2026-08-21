# ─── Autenticacao do GitHub Actions via OIDC ──────────────────────────────────
#
# O caminho tradicional seria criar um IAM User, gerar AWS_ACCESS_KEY_ID +
# AWS_SECRET_ACCESS_KEY e colar como secret no GitHub. Funciona, mas a chave
# nunca expira, fica copiada num sistema de terceiro, e se vazar (log, print,
# fork) alguem tem a conta inteira.
#
# Com OIDC nao existe chave. O fluxo:
#   1. o runner do GitHub gera um JWT assinado dizendo "sou a execucao do repo X
#      na branch Y"; esse token vale minutos;
#   2. a action configure-aws-credentials manda o token para o STS pedindo para
#      vestir esta role;
#   3. a AWS valida a assinatura contra o Identity Provider abaixo;
#   4. a AWS confere a trust policy (o `sub` bate com um dos 4 repos?);
#   5. o STS devolve credencial temporaria de 1 hora.
#
# O que autentica e a identidade da execucao, nao um segredo guardado.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # A AWS deixou de validar thumbprint para o GitHub (ela confia na CA raiz),
  # mas o argumento segue aceito. Mantido por compatibilidade com versoes do
  # provider que ainda o exigem.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "${var.project}-github-actions"
  }
}

# ─── Trust policy: QUEM pode vestir a role ────────────────────────────────────
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Sem esta condicao, um token OIDC do GitHub emitido para QUALQUER audiencia
    # seria aceito.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # O `sub` do token tem o formato classico:
    #   repo:<org>/<repo>:ref:refs/heads/<branch>
    #
    # MAS esta organizacao usa IDs imutaveis, entao o que o GitHub realmente
    # emite e:
    #   repo:<org>@<org_id>/<repo>@<repo_id>:ref:refs/heads/<branch>
    #
    # Confirmado via CloudTrail:
    #   repo:TechChallengeFase1@267126556/garageos-infra-database@1330333756:ref:refs/heads/main
    #
    # Os IDs sao imutaveis de proposito: se o repo for renomeado e outra pessoa
    # registrar o nome antigo, ela nao herda este acesso. Como cada repo tem um
    # ID diferente, eles sao casados com curinga - os NOMES da org e do repo
    # seguem explicitos. Nome de organizacao no GitHub nao pode conter "@",
    # entao "<org>@*" so casa com "<org>@<digitos>".
    #
    # Os dois formatos ficam aceitos, para o caso de a configuracao de IDs
    # imutaveis ser desligada na organizacao mais tarde.
    #
    # O sufixo ":*" aceita qualquer branch/tag/PR. Para restringir producao a
    # uma branch, troque o final por ":ref:refs/heads/main".
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = concat(
        [for repo in var.github_repos : "repo:${var.github_org}/${repo}:*"],
        [for repo in var.github_repos : "repo:${var.github_org}@*/${repo}@*:*"],
      )
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project}-github-actions"
  description        = "Assumida pelo GitHub Actions dos 4 repos do GarageOS via OIDC"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# ─── Permissions policy: O QUE a role pode fazer ──────────────────────────────
#
# DECISAO CONSCIENTE, registrada em ADR:
# Montar least-privilege para EKS + RDS + VPC + Lambda + API Gateway e trabalho
# de horas e gera erros de permissao intermitentes no meio de applies longos.
# PowerUserAccess cobre todos os servicos mas NAO cobre IAM - e EKS, RDS e
# Lambda precisam criar service roles. Dai a policy complementar abaixo,
# restrita a criacao de roles de servico.
#
# Em producao real isso seria least-privilege por repo. Aqui e uma role so para
# os 4 repos, pelo prazo da fase.

resource "aws_iam_role_policy_attachment" "power_user" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "service_roles" {
  statement {
    sid    = "GerenciarServiceRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:CreateServiceLinkedRole",
      "iam:UpdateAssumeRolePolicy",

      # Instance profiles. Necessario mesmo sem usa-los diretamente: ao APAGAR
      # uma role, o provider da AWS primeiro consulta se ha instance profile
      # anexado a ela. Sem ListInstanceProfilesForRole, o destroy falha com
      # AccessDenied depois de ja ter destruido o cluster - deixando as roles
      # orfas no state.
      #
      # As demais acoes da familia entram junto para nao repetir a mesma ida e
      # volta quando algum recurso realmente precisar de instance profile.
      "iam:ListInstanceProfilesForRole",
      "iam:GetInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = ["*"]
  }

  # PassRole e o que permite entregar uma role a um servico (ex.: dar a role de
  # execucao para a Lambda, ou a role do node group para o EKS).
  statement {
    sid       = "PassRoleParaServicos"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  # Necessario para o IRSA do EKS (service accounts do cluster assumindo roles).
  statement {
    sid    = "OidcDoCluster"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "service_roles" {
  name   = "gerenciar-service-roles"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.service_roles.json
}
