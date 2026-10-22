# ---------------------------------------------------------------------
# Logs: Fluent Bit (EC2) -> S3 bronze -> Glue + Athena
#   - fluent-bit/            configuração (fontes, parsers, Lua, install.sh)
#   - scripts/fluentbit_setup.sh.tftpl   embute a config no user_data
#   - modules/logs_pipeline  Glue Catalog, Job bronze->silver, Athena
# ---------------------------------------------------------------------

locals {
  fluentbit_files = {
    install_sh     = file("${path.module}/fluent-bit/install.sh")
    main_conf      = file("${path.module}/fluent-bit/fluent-bit.conf")
    inputs_system  = file("${path.module}/fluent-bit/inputs-system.conf")
    inputs_docker  = file("${path.module}/fluent-bit/inputs-docker.conf")
    inputs_mysql   = file("${path.module}/fluent-bit/inputs-mysql.conf")
    parsers        = file("${path.module}/fluent-bit/parsers_familia.conf")
    lua            = file("${path.module}/fluent-bit/familia.lua")
  }

  # chave = nome lógico da instância; role define quais fontes são lidas
  fluentbit_nodes = {
    front_a = { role = "front",   hostname = "fc-front-a" }
    front_b = { role = "front",   hostname = "fc-front-b" }
    back_a  = { role = "back",    hostname = "fc-back-a" }
    back_b  = { role = "back",    hostname = "fc-back-b" }
    ocr_a   = { role = "ocr",     hostname = "fc-ocr-a" }
    ocr_b   = { role = "ocr",     hostname = "fc-ocr-b" }
    db      = { role = "db",      hostname = "fc-db" }
    bastion = { role = "bastion", hostname = "fc-bastion" }
  }

  fluentbit_setup = {
    for k, n in local.fluentbit_nodes : k => templatefile(
      "${path.module}/scripts/fluentbit_setup.sh.tftpl",
      merge(local.fluentbit_files, {
        role          = n.role
        node_hostname = n.hostname
        bucket        = var.s3_bronze_bucket_name
        region        = var.aws_region
      })
    )
  }
}

module "logs_pipeline" {
  source = "./modules/logs_pipeline"

  # ids vêm do módulo storage => os buckets existem antes das tabelas/jobs
  bronze_bucket = module.storage.bucket_ids["bronze"]
  silver_bucket = module.storage.bucket_ids["silver"]

  glue_role_name = var.glue_role_name
  job_schedule   = var.logs_job_schedule
}

output "logs_athena_workgroup" {
  value       = module.logs_pipeline.athena_workgroup
  description = "Workgroup do Athena para consultar os logs"
}

output "logs_glue_database" {
  value = module.logs_pipeline.database_name
}

output "logs_glue_job" {
  value       = module.logs_pipeline.glue_job_name
  description = "Job Glue bronze->silver (rode manualmente com --process_date AAAA-MM-DD para reprocessar)"
}
