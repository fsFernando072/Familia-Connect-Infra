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
  value = module.compute.instance_ids["front_a"]
}

output "instance_front_b_id" {
  value = module.compute.instance_ids["front_b"]
}

output "instance_back_a_id" {
  value = module.compute.instance_ids["back_a"]
}

output "instance_back_b_id" {
  value = module.compute.instance_ids["back_b"]
}

output "instance_db_id" {
  value = module.compute.instance_ids["db"]
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
