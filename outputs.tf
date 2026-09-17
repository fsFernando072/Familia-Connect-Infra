output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_public_a_id" {
  value = module.network.public_subnet_a_id
}

output "subnet_public_b_id" {
  value = module.network.public_subnet_b_id
}

output "subnet_front_a_id" {
  value = module.network.front_subnet_a_id
}

output "subnet_front_b_id" {
  value = module.network.front_subnet_b_id
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
  value = module.compute_db.instance_ids["db"]
}

output "instance_ocr_a_id" {
  value = module.compute_ocr.instance_ids["ocr_a"]
}

output "instance_ocr_b_id" {
  value = module.compute_ocr.instance_ids["ocr_b"]
}

output "db_private_ip" {
  description = "IP privado da instância db (10.0.7.10), usado pelo backend em DB_URL"
  value       = module.compute_db.private_ips["db"]
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

output "lb_ocr_dns_name" {
  value = module.lb_ocr.dns_name
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

output "swarm_manager_ip" {
  description = "IP privado fixo do manager inicial do Docker Swarm (Front A)"
  value       = local.swarm_manager_ip
}

output "swarm_manager_token_parameter" {
  description = "SSM Parameter Store com o token de manager do Swarm"
  value       = local.swarm_manager_parameter
}

output "swarm_worker_token_parameter" {
  description = "SSM Parameter Store com o token de worker do Swarm"
  value       = local.swarm_worker_parameter
}
