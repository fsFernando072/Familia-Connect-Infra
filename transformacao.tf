# ---------------------------------------------------------------------
# Transformação — Athena (bronze -> silver -> gold)
#   silver: bases tratadas (nulos, tipos) e anos unificados em uma tabela por base
#   gold  : visões analíticas (SP por distrito e SP anual, juntando as duas bases)
# SQLs em lambda/transformacao/sql/
# ---------------------------------------------------------------------
variable "transformacao_executar_no_apply" {
  type        = bool
  default     = false
  description = "Se true, executa as transformações no terraform apply (precisa de dados no bronze: rode a ingestão antes)"
}

module "transformacao" {
  source = "./modules/transformacao"

  source_dir        = "${path.module}/lambda/transformacao"
  role_name         = var.lambda_role_name
  bronze_bucket     = module.storage.bucket_ids["bronze"]
  silver_bucket     = module.storage.bucket_ids["silver"]
  gold_bucket       = module.storage.bucket_ids["gold"]
  executar_no_apply = var.transformacao_executar_no_apply
  depende_de        = var.ingestao_executar_no_apply ? module.ingestao.function_arn : null
}

output "athena_database" {
  value = module.transformacao.database_name
}

output "athena_workgroup" {
  value = module.transformacao.workgroup_name
}

output "lambda_transformacao_invoke_cmd" {
  description = "Comando para rodar as transformações manualmente (após a ingestão)"
  value       = "aws lambda invoke --function-name ${module.transformacao.function_name} --cli-read-timeout 900 --region ${var.aws_region} out.json"
}
