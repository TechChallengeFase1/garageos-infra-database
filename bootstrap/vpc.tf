# ─── Rede onde EKS e RDS vao viver ────────────────────────────────────────────
#
# Escrito com resources crus, sem o modulo terraform-aws-modules/vpc. O valor do
# modulo esta em cenarios com NAT em multiplas AZs, VPC endpoints e flow logs -
# complexidade que esta VPC nao tem. Aqui sao ~70 linhas legiveis, e voce
# consegue apontar o que cada recurso faz na defesa do trabalho.
#
# DECISAO CONSCIENTE: sem NAT Gateway (~US$ 32/mes ligado 24h, quase um terco do
# orcamento de creditos). Consequencia:
#   - nos do EKS vao nas subnets PUBLICAS, com IP publico protegido por
#     Security Group;
#   - o RDS fica nas PRIVADAS, sem rota para a internet - ele nao precisa.
# Em producao real os nos ficariam privados atras de NAT. Registrado em ADR.

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support = true
  # Obrigatorio para o RDS ser resolvido pelo endpoint DNS em vez de IP.
  enable_dns_hostnames = true

  tags = {
    Name = var.project
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# ─── Subnets publicas ─────────────────────────────────────────────────────────
# cidrsubnet("10.0.0.0/16", 8, 0) => 10.0.0.0/24  (us-east-1a)
# cidrsubnet("10.0.0.0/16", 8, 1) => 10.0.1.0/24  (us-east-1b)
resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-${var.azs[count.index]}"

    # ARMADILHA: sem esta tag, o EKS nao descobre onde criar Load Balancers
    # publicos. Um Service type: LoadBalancer fica <pending> para sempre, sem
    # mensagem de erro util.
    "kubernetes.io/role/elb" = "1"
  }
}

# ─── Subnets privadas ─────────────────────────────────────────────────────────
# cidrsubnet("10.0.0.0/16", 8, 10) => 10.0.10.0/24 (us-east-1a)
# cidrsubnet("10.0.0.0/16", 8, 11) => 10.0.11.0/24 (us-east-1b)
resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project}-private-${var.azs[count.index]}"

    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ─── Roteamento ───────────────────────────────────────────────────────────────
# Nao existe um campo "is_public" numa subnet. E a ROTA que define: ter ou nao
# ter caminho para o Internet Gateway.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Tabela privada sem nenhuma rota para 0.0.0.0/0: e isso que torna a subnet
# privada. Trafego interno da VPC continua funcionando (rota "local" implicita),
# entao os nos do EKS alcancam o RDS normalmente.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-private"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
