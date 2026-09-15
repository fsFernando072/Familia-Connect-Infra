# ---------------------------------------------------------------------
# Gera um par de chaves RSA (equivalente ao AWS::EC2::KeyPair da CFN,
# que gera a chave automaticamente e guarda no SSM Parameter Store).
# ---------------------------------------------------------------------
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.this.public_key_openssh

  tags = {
    Name = var.key_name
  }
}

# Guarda a chave privada no SSM Parameter Store, no mesmo padrão usado
# pela CFN (/ec2/keypair/{KeyPairId}), para não deixar a chave só local.
resource "aws_ssm_parameter" "private_key" {
  name  = "/ec2/keypair/${aws_key_pair.this.key_pair_id}"
  type  = "SecureString"
  value = tls_private_key.this.private_key_pem

  tags = {
    Name = var.key_name
  }
}
