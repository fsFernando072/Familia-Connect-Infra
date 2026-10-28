# ---------------------------------------------------------------------
# Glue — tratamento bronze -> silver
#   Lê os CSVs do bucket bronze (gravados pela Lambda de ingestão), trata nulos/tipos,
#   junta os anos de cada base e grava Parquet no bucket silver:
#     s3://silver/cadunico/ano=AAAA/          (familias-cadastro-unico)
#     s3://silver/bolsa-familia-sp/ano=AAAA/  (bolsa-familia-sp)
# Script: glue/transformacao/transformacao_silver.py
# ---------------------------------------------------------------------
module "glue" {
  source = "./modules/glue"

  script_path   = "${path.module}/glue/transformacao/transformacao_silver.py"
  role_name     = var.lambda_role_name
  bronze_bucket = module.storage.bucket_ids["bronze"]
  silver_bucket = module.storage.bucket_ids["silver"]
}

output "glue_job_name" {
  value = module.glue.job_name
}

output "glue_job_run_cmd" {
  description = "Comando para rodar o tratamento manualmente (após a ingestão)"
  value       = "aws glue start-job-run --job-name ${module.glue.job_name} --region ${var.aws_region}"
}
