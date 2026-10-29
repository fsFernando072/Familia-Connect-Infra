# ---------------------------------------------------------------------
# Athena — consulta à camada silver (tabelas catalogadas pelo crawler do Glue)
#   Resultado das consultas : s3://<silver>/athena-results/
#   Exports (UNLOAD / CTAS) : s3://<silver>/export/
# Requer glue.tf com enable_crawler = true (é ele que cria o banco do Data Catalog).
# ---------------------------------------------------------------------
module "athena" {
  source = "./modules/athena"

  silver_bucket = module.storage.bucket_ids["silver"]
  database_name = module.glue.database_name
}

output "athena_workgroup" {
  description = "Workgroup do Athena (selecione-o no console antes de consultar)"
  value       = module.athena.workgroup_name
}

output "athena_results_location" {
  value = module.athena.results_location
}

output "athena_export_location" {
  description = "Pasta no bucket silver para exports diretos (UNLOAD / CTAS)"
  value       = module.athena.export_location
}

output "athena_query_cmd" {
  description = "Exemplo de consulta pela CLI"
  value       = "aws athena start-query-execution --work-group ${module.athena.workgroup_name} --query-execution-context Database=${module.glue.database_name} --query-string \"SELECT ano, COUNT(*) FROM cadunico GROUP BY ano ORDER BY ano\" --region ${var.aws_region}"
}
