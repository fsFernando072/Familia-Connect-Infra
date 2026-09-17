# ---------------------------------------------------------------------
# ALB Front — público
# ---------------------------------------------------------------------
resource "aws_security_group" "front_alb" {
  name = "front-alb-sg"
  description = "ALB publico do frontend"
  vpc_id = var.vpc_id

  ingress {
    description = "HTTP da internet"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS da internet"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "front-alb-sg" }
}

# ---------------------------------------------------------------------
# EC2 Front — recebe somente do ALB público
# ---------------------------------------------------------------------
resource "aws_security_group" "front" {
  name = "front-sg"
  description = "Frontend privado"
  vpc_id = var.vpc_id

  ingress {
    description = "HTTP vindo do ALB Front"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.front_alb.id]
  }

  ingress {
    description = "SSH para administracao"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Docker Swarm control plane"
    from_port = 2377
    to_port = 2377
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm node communication TCP"
    from_port = 7946
    to_port = 7946
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm node communication UDP"
    from_port = 7946
    to_port = 7946
    protocol = "udp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm overlay VXLAN"
    from_port = 4789
    to_port = 4789
    protocol = "udp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "front-sg" }
}

# ---------------------------------------------------------------------
# ALB Back — interno
# ---------------------------------------------------------------------
resource "aws_security_group" "back_alb" {
  name = "back-alb-sg"
  description = "ALB interno do backend"
  vpc_id = var.vpc_id

  ingress {
    description = "Backend vindo do Front"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [aws_security_group.front.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "back-alb-sg" }
}

# ---------------------------------------------------------------------
# EC2 Back — recebe somente do ALB Back
# ---------------------------------------------------------------------
resource "aws_security_group" "back" {
  name = "back-sg"
  description = "Backend privado"
  vpc_id = var.vpc_id

  ingress {
    description = "HTTP do ALB Back"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [aws_security_group.back_alb.id]
  }

  ingress {
    description = "SSH para administracao"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Docker Swarm control plane"
    from_port = 2377
    to_port = 2377
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm node communication TCP"
    from_port = 7946
    to_port = 7946
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm node communication UDP"
    from_port = 7946
    to_port = 7946
    protocol = "udp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm overlay VXLAN"
    from_port = 4789
    to_port = 4789
    protocol = "udp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "back-sg" }
}

# ---------------------------------------------------------------------
# ALB OCR — interno
# ---------------------------------------------------------------------
resource "aws_security_group" "ocr_alb" {
  name = "ocr-alb-sg"
  description = "ALB interno do OCR"
  vpc_id = var.vpc_id

  ingress {
    description = "OCR vindo do Backend"
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    security_groups = [aws_security_group.back.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ocr-alb-sg" }
}

# ---------------------------------------------------------------------
# EC2 OCR — recebe somente do ALB OCR
# ---------------------------------------------------------------------
resource "aws_security_group" "ocr" {
  name = "ocr-sg"
  description = "OCR privado"
  vpc_id = var.vpc_id

  ingress {
    description = "OCR do ALB OCR"
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    security_groups = [aws_security_group.ocr_alb.id]
  }

  ingress {
    description = "SSH para administracao"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Docker Swarm control plane"
    from_port = 2377
    to_port = 2377
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm node communication TCP"
    from_port = 7946
    to_port = 7946
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm node communication UDP"
    from_port = 7946
    to_port = 7946
    protocol = "udp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Docker Swarm overlay VXLAN"
    from_port = 4789
    to_port = 4789
    protocol = "udp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ocr-sg" }
}

# ---------------------------------------------------------------------
# Banco — recebe MySQL somente do Backend
# ---------------------------------------------------------------------
resource "aws_security_group" "db" {
  name = "db-sg"
  description = "Database privado"
  vpc_id = var.vpc_id

  ingress {
    description = "MySQL vindo do Backend"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.back.id]
  }

  ingress {
    description = "SSH para administracao"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "db-sg" }
}
