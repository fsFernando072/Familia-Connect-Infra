output "instance_ids" {
  description = "Mapa nome_logico => id da instância"
  value       = { for k, v in aws_instance.this : k => v.id }
}

output "private_ips" {
  value = { for k, v in aws_instance.this : k => v.private_ip }
}

output "public_ips" {
  description = "IP elástico (quando associate_eip = true) de cada instância"
  value       = { for k, v in aws_eip.this : k => v.public_ip }
}
