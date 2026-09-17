# ---------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.vpc_name }
}

# ---------------------------------------------------------------------
# Sub-redes — conforme diagrama
# ---------------------------------------------------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "sub-rede-publica-A" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "sub-rede-publica-B" }
}

resource "aws_subnet" "front_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.front_subnet_a_cidr
  availability_zone = var.azs[0]
  tags              = { Name = "sub-rede-front-A" }
}

resource "aws_subnet" "front_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.front_subnet_b_cidr
  availability_zone = var.azs[1]
  tags              = { Name = "sub-rede-front-B" }
}

resource "aws_subnet" "back_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.back_subnet_a_cidr
  availability_zone = var.azs[0]
  tags              = { Name = "sub-rede-back-A" }
}

resource "aws_subnet" "back_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.back_subnet_b_cidr
  availability_zone = var.azs[1]
  tags              = { Name = "sub-rede-back-B" }
}

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_subnet_a_cidr
  availability_zone = var.azs[0]
  tags              = { Name = "sub-rede-db-A" }
}

# ---------------------------------------------------------------------
# Internet Gateway + rotas públicas
# ---------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-rtb-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_a.id
}

resource "aws_route_table_association" "public_b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_b.id
}

# ---------------------------------------------------------------------
# NAT Gateway — um por AZ, conforme diagrama
# ---------------------------------------------------------------------
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags   = { Name = "${var.vpc_name}-nat-a-eip" }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags   = { Name = "${var.vpc_name}-nat-b-eip" }
}

resource "aws_nat_gateway" "a" {
  subnet_id     = aws_subnet.public_a.id
  allocation_id = aws_eip.nat_a.id
  depends_on    = [aws_internet_gateway.this]
  tags          = { Name = "${var.vpc_name}-natgw-a" }
}

resource "aws_nat_gateway" "b" {
  subnet_id     = aws_subnet.public_b.id
  allocation_id = aws_eip.nat_b.id
  depends_on    = [aws_internet_gateway.this]
  tags          = { Name = "${var.vpc_name}-natgw-b" }
}

# ---------------------------------------------------------------------
# Route tables privadas por AZ
# Front, Back e DB permanecem privados e saem pela NAT da própria AZ.
# ---------------------------------------------------------------------
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-rtb-private-a" }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-rtb-private-b" }
}

resource "aws_route" "private_a_nat" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.a.id
}

resource "aws_route" "private_b_nat" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.b.id
}

resource "aws_route_table_association" "front_a" {
  route_table_id = aws_route_table.private_a.id
  subnet_id      = aws_subnet.front_a.id
}

resource "aws_route_table_association" "back_a" {
  route_table_id = aws_route_table.private_a.id
  subnet_id      = aws_subnet.back_a.id
}

resource "aws_route_table_association" "db_a" {
  route_table_id = aws_route_table.private_a.id
  subnet_id      = aws_subnet.db_a.id
}

resource "aws_route_table_association" "front_b" {
  route_table_id = aws_route_table.private_b.id
  subnet_id      = aws_subnet.front_b.id
}

resource "aws_route_table_association" "back_b" {
  route_table_id = aws_route_table.private_b.id
  subnet_id      = aws_subnet.back_b.id
}

# ---------------------------------------------------------------------
# NACLs — regras por camada. Como NACL é stateless, cada camada permite
# as portas de serviço e o retorno por portas efêmeras.
# ---------------------------------------------------------------------
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "acl-publica" }
}

resource "aws_network_acl_association" "public_a" {
  network_acl_id = aws_network_acl.public.id
  subnet_id      = aws_subnet.public_a.id
}
resource "aws_network_acl_association" "public_b" {
  network_acl_id = aws_network_acl.public.id
  subnet_id      = aws_subnet.public_b.id
}

resource "aws_network_acl_rule" "public_in_80" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}
resource "aws_network_acl_rule" "public_in_443" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}
resource "aws_network_acl_rule" "public_in_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
resource "aws_network_acl_rule" "public_out_all" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl" "front" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "acl-front" }
}
resource "aws_network_acl_association" "front_a" {
  network_acl_id = aws_network_acl.front.id
  subnet_id      = aws_subnet.front_a.id
}
resource "aws_network_acl_association" "front_b" {
  network_acl_id = aws_network_acl.front.id
  subnet_id      = aws_subnet.front_b.id
}
resource "aws_network_acl_rule" "front_in_80" {
  network_acl_id = aws_network_acl.front.id
  rule_number    = 100
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}
resource "aws_network_acl_rule" "front_in_8080" {
  network_acl_id = aws_network_acl.front.id
  rule_number    = 105
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 8080
  to_port        = 8080
}
resource "aws_network_acl_rule" "front_in_swarm_2377" {
  network_acl_id = aws_network_acl.front.id
  rule_number    = 115
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 2377
  to_port        = 2377
}
resource "aws_network_acl_rule" "front_in_swarm_7946_tcp" {
  network_acl_id = aws_network_acl.front.id
  rule_number    = 120
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 7946
  to_port        = 7946
}
resource "aws_network_acl_rule" "front_in_swarm_7946_udp" {
  network_acl_id = aws_network_acl.front.id
  rule_number    = 125
  egress         = false
  protocol       = "17"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 7946
  to_port        = 7946
}
resource "aws_network_acl_rule" "front_in_swarm_4789_udp" {
  network_acl_id = aws_network_acl.front.id
  rule_number    = 130
  egress         = false
  protocol       = "17"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 4789
  to_port        = 4789
}
resource "aws_network_acl_rule" "front_in_ephemeral" {
  network_acl_id = aws_network_acl.front.id
  rule_number    = 110
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
resource "aws_network_acl_rule" "front_out_all" {
  network_acl_id = aws_network_acl.front.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl" "back" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "acl-back" }
}
resource "aws_network_acl_association" "back_a" {
  network_acl_id = aws_network_acl.back.id
  subnet_id      = aws_subnet.back_a.id
}
resource "aws_network_acl_association" "back_b" {
  network_acl_id = aws_network_acl.back.id
  subnet_id      = aws_subnet.back_b.id
}
resource "aws_network_acl_rule" "back_in_8080" {
  network_acl_id = aws_network_acl.back.id
  rule_number    = 100
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 8080
  to_port        = 8080
}
resource "aws_network_acl_rule" "back_in_8000" {
  network_acl_id = aws_network_acl.back.id
  rule_number    = 105
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 8000
  to_port        = 8000
}
resource "aws_network_acl_rule" "back_in_swarm_2377" {
  network_acl_id = aws_network_acl.back.id
  rule_number    = 115
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 2377
  to_port        = 2377
}
resource "aws_network_acl_rule" "back_in_swarm_7946_tcp" {
  network_acl_id = aws_network_acl.back.id
  rule_number    = 120
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 7946
  to_port        = 7946
}
resource "aws_network_acl_rule" "back_in_swarm_7946_udp" {
  network_acl_id = aws_network_acl.back.id
  rule_number    = 125
  egress         = false
  protocol       = "17"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 7946
  to_port        = 7946
}
resource "aws_network_acl_rule" "back_in_swarm_4789_udp" {
  network_acl_id = aws_network_acl.back.id
  rule_number    = 130
  egress         = false
  protocol       = "17"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 4789
  to_port        = 4789
}
resource "aws_network_acl_rule" "back_in_ephemeral" {
  network_acl_id = aws_network_acl.back.id
  rule_number    = 110
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
resource "aws_network_acl_rule" "back_out_all" {
  network_acl_id = aws_network_acl.back.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl" "db" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "acl-db" }
}
resource "aws_network_acl_association" "db_a" {
  network_acl_id = aws_network_acl.db.id
  subnet_id      = aws_subnet.db_a.id
}
resource "aws_network_acl_rule" "db_in_3306" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 3306
  to_port        = 3306
}
resource "aws_network_acl_rule" "db_in_ephemeral" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 110
  egress         = false
  protocol       = "6"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
resource "aws_network_acl_rule" "db_out_all" {
  network_acl_id = aws_network_acl.db.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}
