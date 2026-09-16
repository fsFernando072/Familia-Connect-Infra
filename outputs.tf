output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_public_a_id" {
  value = module.network.public_subnet_a_id
}

output "subnet_public_b_id" {
  value = module.network.public_subnet_b_id
}

output "subnet_back_a_id" {
  value = module.network.back_subnet_a_id
}

output "subnet_back_b_id" {
  value = module.network.back_subnet_b_id
}

output "subnet_db_a_id" {
  value = module.network.db_subnet_a_id
}

output "key_pair_id" {
  value       = module.keypair.key_pair_id
  description = "ID do par de chaves. A chave privada fica salva no SSM Parameter Store."
}

output "key_pair_ssm_parameter" {
  value = module.keypair.ssm_parameter_name
}

output "instance_front_a_id" {
  value = module.compute_front.instance_ids["front_a"]
}

output "instance_front_b_id" {
  value = module.compute_front.instance_ids["front_b"]
}

output "instance_back_a_id" {
  value = module.compute_back.instance_ids["back_a"]
}

output "instance_back_b_id" {
  value = module.compute_back.instance_ids["back_b"]
}

output "instance_db_id" {
  value = module.compute_core.instance_ids["db"]
}

output "instance_ocr_a_id" {
  value = module.compute_core.instance_ids["ocr_a"]
}

output "instance_ocr_b_id" {
  value = module.compute_core.instance_ids["ocr_b"]
}

output "db_private_ip" {
  description = "IP privado (dinâmico) da instância db, usado pelo backend em DB_URL"
  value       = module.compute_core.private_ips["db"]
}

output "ocr_private_ip" {
  description = "IP privado (dinâmico) da instância ocr_a, usado pelo backend em URL_OCR_SERVICE"
  value       = module.compute_core.private_ips["ocr_a"]
}

output "api_base_url" {
  description = "URL usada pelo front (API_BASE_URL) para falar com o ALB interno do back"
  value       = local.api_base_url
}

output "lb_front_dns_name" {
  value = module.lb_front.dns_name
}

output "lb_back_dns_name" {
  value = module.lb_back.dns_name
}

output "s3_bronze_bucket" {
  value = module.storage.bucket_ids["bronze"]
}

output "s3_silver_bucket" {
  value = module.storage.bucket_ids["silver"]
}

output "s3_gold_bucket" {
  value = module.storage.bucket_ids["gold"]
}

output "alerts_topic_arn" {
  value = module.monitoring.alerts_topic_arn
}
