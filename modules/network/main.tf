# ---------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# ---------------------------------------------------------------------
# Sub-redes
# ---------------------------------------------------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block               = var.public_subnet_a_cidr
  availability_zone        = var.azs[0]
  map_public_ip_on_launch  = true

  tags = {
    Name = "sub-rede-publica-A"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block               = var.public_subnet_b_cidr
  availability_zone        = var.azs[1]
  map_public_ip_on_launch  = true

  tags = {
    Name = "sub-rede-publica-B"
  }
}

resource "aws_subnet" "back_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.back_subnet_a_cidr
  availability_zone = var.azs[0]

  tags = {
    Name = "sub-rede-back-A"
  }
}

resource "aws_subnet" "back_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.back_subnet_b_cidr
  availability_zone = var.azs[1]

  tags = {
    Name = "sub-rede-back-B"
  }
}

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_subnet_a_cidr
  availability_zone = var.azs[0]

  tags = {
    Name = "sub-rede-db-A"
  }
}

# ---------------------------------------------------------------------
# Internet Gateway + Rotas públicas
# ---------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-rtb-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_a" {
  route_table_id = aws_route_table.public.id
  subnet_id       = aws_subnet.public_a.id
}

resource "aws_route_table_association" "public_b" {
  route_table_id = aws_route_table.public.id
  subnet_id       = aws_subnet.public_b.id
}

# ---------------------------------------------------------------------
# NAT Gateway + Rotas privadas
# ---------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  subnet_id      = aws_subnet.public_a.id
  allocation_id  = aws_eip.nat.id

  tags = {
    Name = "${var.vpc_name}-natgw"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-rtb-private"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id          = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "back_a" {
  route_table_id = aws_route_table.private.id
  subnet_id       = aws_subnet.back_a.id
}

resource "aws_route_table_association" "back_b" {
  route_table_id = aws_route_table.private.id
  subnet_id       = aws_subnet.back_b.id
}

resource "aws_route_table_association" "db_a" {
  route_table_id = aws_route_table.private.id
  subnet_id       = aws_subnet.db_a.id
}

# ---------------------------------------------------------------------
# Network ACL pública
# ---------------------------------------------------------------------
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "acl-publica"
  }
}

resource "aws_network_acl_association" "public_a" {
  network_acl_id = aws_network_acl.public.id
  subnet_id       = aws_subnet.public_a.id
}

resource "aws_network_acl_association" "public_b" {
  network_acl_id = aws_network_acl.public.id
  subnet_id       = aws_subnet.public_b.id
}

resource "aws_network_acl_rule" "public_in_22" {
  network_acl_id = aws_network_acl.public.id
  rule_number     = 100
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
  from_port       = 22
  to_port         = 22
}

resource "aws_network_acl_rule" "public_in_80" {
  network_acl_id = aws_network_acl.public.id
  rule_number     = 200
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
  from_port       = 80
  to_port         = 80
}

resource "aws_network_acl_rule" "public_in_8080" {
  network_acl_id = aws_network_acl.public.id
  rule_number     = 300
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
  from_port       = 8080
  to_port         = 8080
}

resource "aws_network_acl_rule" "public_in_443" {
  network_acl_id = aws_network_acl.public.id
  rule_number     = 400
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
  from_port       = 443
  to_port         = 443
}

resource "aws_network_acl_rule" "public_in_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number     = 500
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
  from_port       = 32000
  to_port         = 65535
}

resource "aws_network_acl_rule" "public_out_all" {
  network_acl_id = aws_network_acl.public.id
  rule_number     = 100
  egress          = true
  protocol        = "-1"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
}

# ---------------------------------------------------------------------
# Network ACL do back
# ---------------------------------------------------------------------
resource "aws_network_acl" "back" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "acl-back"
  }
}

resource "aws_network_acl_association" "back_a" {
  network_acl_id = aws_network_acl.back.id
  subnet_id       = aws_subnet.back_a.id
}

resource "aws_network_acl_association" "back_b" {
  network_acl_id = aws_network_acl.back.id
  subnet_id       = aws_subnet.back_b.id
}

resource "aws_network_acl_rule" "back_in_22_a" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 100
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_a_cidr
  from_port       = 22
  to_port         = 22
}

resource "aws_network_acl_rule" "back_in_22_b" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 200
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_b_cidr
  from_port       = 22
  to_port         = 22
}

resource "aws_network_acl_rule" "back_in_80_a" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 300
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_a_cidr
  from_port       = 80
  to_port         = 80
}

resource "aws_network_acl_rule" "back_in_80_b" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 400
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_b_cidr
  from_port       = 80
  to_port         = 80
}

resource "aws_network_acl_rule" "back_in_443_a" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 500
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_a_cidr
  from_port       = 443
  to_port         = 443
}

resource "aws_network_acl_rule" "back_in_443_b" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 600
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_b_cidr
  from_port       = 443
  to_port         = 443
}

resource "aws_network_acl_rule" "back_in_8080_a" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 700
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_a_cidr
  from_port       = 8080
  to_port         = 8080
}

resource "aws_network_acl_rule" "back_in_8080_b" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 800
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_b_cidr
  from_port       = 8080
  to_port         = 8080
}

resource "aws_network_acl_rule" "back_in_ephemeral" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 900
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
  from_port       = 32000
  to_port         = 65535
}

resource "aws_network_acl_rule" "back_out_all" {
  network_acl_id = aws_network_acl.back.id
  rule_number     = 100
  egress          = true
  protocol        = "-1"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
}

# ---------------------------------------------------------------------
# Network ACL do banco de dados
# ---------------------------------------------------------------------
resource "aws_network_acl" "db" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "acl-db"
  }
}

resource "aws_network_acl_association" "db_a" {
  network_acl_id = aws_network_acl.db.id
  subnet_id       = aws_subnet.db_a.id
}

resource "aws_network_acl_rule" "db_in_22_a" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 100
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.back_subnet_a_cidr
  from_port       = 22
  to_port         = 22
}

resource "aws_network_acl_rule" "db_in_22_b" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 200
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.back_subnet_b_cidr
  from_port       = 22
  to_port         = 22
}

resource "aws_network_acl_rule" "db_in_80_a" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 300
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.back_subnet_a_cidr
  from_port       = 80
  to_port         = 80
}

resource "aws_network_acl_rule" "db_in_80_b" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 400
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.back_subnet_b_cidr
  from_port       = 80
  to_port         = 80
}

resource "aws_network_acl_rule" "db_in_3306_a" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 500
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.back_subnet_a_cidr
  from_port       = 3306
  to_port         = 3306
}

resource "aws_network_acl_rule" "db_in_3306_b" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 600
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.back_subnet_b_cidr
  from_port       = 3306
  to_port         = 3306
}

resource "aws_network_acl_rule" "db_in_443_a" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 700
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_a_cidr
  from_port       = 443
  to_port         = 443
}

resource "aws_network_acl_rule" "db_in_443_b" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 800
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.public_subnet_b_cidr
  from_port       = 443
  to_port         = 443
}

resource "aws_network_acl_rule" "db_in_8080_a" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 900
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.back_subnet_a_cidr
  from_port       = 8080
  to_port         = 8080
}

resource "aws_network_acl_rule" "db_in_8080_b" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 1000
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = var.back_subnet_b_cidr
  from_port       = 8080
  to_port         = 8080
}

resource "aws_network_acl_rule" "db_in_ephemeral" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 1100
  egress          = false
  protocol        = "6"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
  from_port       = 32000
  to_port         = 65535
}

resource "aws_network_acl_rule" "db_out_all" {
  network_acl_id = aws_network_acl.db.id
  rule_number     = 100
  egress          = true
  protocol        = "-1"
  rule_action     = "allow"
  cidr_block      = "0.0.0.0/0"
}
