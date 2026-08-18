# Bootstrap — fundação da AWS

> **Esta pasta não é aplicada pelo CI/CD.** Roda uma vez só, manualmente, da máquina
> de quem está montando o projeto. A raiz deste repositório (o RDS) é que roda pela
> pipeline.

## Por que é manual

Ovo e galinha: os workflows autenticam na AWS via OIDC, mas o provedor OIDC e a IAM
Role são justamente duas das coisas que esta pasta cria. Alguém precisa criar o
primeiro recurso com uma credencial de verdade.

O mesmo vale para o state: o bucket S3 que guarda o state de todos os repositórios é
criado aqui — então o primeiro `apply` roda com state local, e só depois o state é
migrado para dentro do bucket recém-criado.

## O que provisiona

| Arquivo | Recursos | Para quê |
|---|---|---|
| `s3-state.tf` | Bucket S3 versionado e criptografado | State remoto dos 4 repositórios, isolados por prefixo |
| `oidc.tf` | OIDC Identity Provider + IAM Role | GitHub Actions autentica sem `AWS_ACCESS_KEY_ID` |
| `vpc.tf` | VPC, 2 subnets públicas, 2 privadas, IGW, route tables | Rede onde EKS e RDS vivem |
| `ssm.tf` | Parâmetros no SSM Parameter Store | Como os outros repos descobrem os IDs criados aqui |

Custo: praticamente zero. S3, IAM, VPC e Parameter Store não têm cobrança fixa
relevante. O gasto começa no RDS e no EKS.

## Como executar

### 1. Pré-requisito

```bash
aws sts get-caller-identity
```

Precisa retornar o JSON com a sua conta. Sem isso, todo comando abaixo falha com
`NoCredentials`.

### 2. Primeiro apply (state local)

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

Leia o `plan` antes de confirmar. Procure por `Plan: N to add, 0 to change, 0 to
destroy` — qualquer `destroy` num apply inicial significa que algo está errado.

### 3. Migrar o state para o S3

O output `backend_config` imprime o bloco pronto. Cole-o dentro do bloco `terraform`
em `versions.tf` (substituindo o trecho comentado), e então:

```bash
terraform init -migrate-state
```

Responda `yes` quando ele perguntar se quer copiar o state para o novo backend.
Depois apague o arquivo local:

```bash
rm terraform.tfstate terraform.tfstate.backup
```

### 4. Validar o OIDC antes de confiar nele

Este passo não é opcional. Crie um workflow descartável em qualquer um dos 4 repos:

```yaml
name: Teste OIDC
on: workflow_dispatch

permissions:
  id-token: write
  contents: read

jobs:
  teste:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: <cole aqui o output github_actions_role_arn>
          aws-region: us-east-1
      - run: aws sts get-caller-identity
```

Rode pelo botão "Run workflow". Se retornar o ARN da role, o mecanismo funciona.
Se der `Not authorized to perform sts:AssumeRoleWithWebIdentity`, o erro está no
`sub` da trust policy em `oidc.tf`.

Depurar isso num workflow de 10 linhas leva minutos. Depurar o mesmo erro no meio de
um `terraform apply` de EKS, que leva 15 minutos por tentativa, custa a tarde inteira.

## Decisões registradas

Cada uma vira um ADR na documentação da fase.

**Bootstrap mora aqui, e não num 5º repositório.** O enunciado exige exatamente 4
repositórios. Um quinto repo poderia ser lido como desorganização. Esta pasta é uma
raiz Terraform independente da raiz do repo — states separados, ciclos de vida
separados.

**Sem NAT Gateway.** Custaria ~US$ 32/mês ligado 24h, quase um terço do orçamento de
créditos. Consequência: os nós do EKS ficam em subnets públicas, com IP público
protegido por Security Group, e o RDS fica nas privadas sem rota para a internet. Em
produção real os nós ficariam privados atrás de NAT.

**Uma IAM Role para os 4 repositórios.** O correto seria uma role por repo, com
menor privilégio — o repositório do banco não deveria poder mexer no cluster. Uma
role só foi escolhida pelo prazo da fase.

**`PowerUserAccess` + política complementar de IAM.** Montar least-privilege para
EKS + RDS + VPC + Lambda + API Gateway levaria horas e geraria erros de permissão
intermitentes no meio de applies longos. `PowerUserAccess` cobre os serviços mas não
cobre IAM, e EKS/RDS/Lambda precisam criar service roles — daí a política extra em
`oidc.tf`, restrita a isso.

**Sem tabela DynamoDB para lock.** A partir do Terraform 1.10 o S3 tem lock nativo
(`use_lockfile = true`); o método por DynamoDB está depreciado. Um recurso a menos
para criar, pagar e destruir.

## Desmontar no fim da fase

O bucket de state tem `prevent_destroy = true` de propósito: destruí-lo significa
perder o registro de toda a infraestrutura das outras raízes, que continuaria
existindo na AWS sem ninguém saber.

Ordem correta: destrua primeiro `garageos-infra-k8s` e `garageos-infra-database`
(a raiz), depois comente o bloco `lifecycle` em `s3-state.tf`, rode `terraform
apply`, e só então `terraform destroy` aqui.
