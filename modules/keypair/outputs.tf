output "key_name" {
  value = aws_key_pair.this.key_name
}

output "key_pair_id" {
  value = aws_key_pair.this.key_pair_id
}

output "ssm_parameter_name" {
  value       = aws_ssm_parameter.private_key.name
  description = "Caminho no SSM Parameter Store onde a chave privada foi salva."
}
