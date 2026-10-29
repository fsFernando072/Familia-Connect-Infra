# ---------------------------------------------------------------------
# Athena — consulta às tabelas silver catalogadas pelo Glue crawler
#   Apenas configuração: nenhum objeto é criado no bucket. As pastas abaixo
#   passam a existir no S3 só quando a primeira consulta/export gravar nelas:
#     s3://<silver>/athena-results/   resultado (CSV) de cada consulta
#     s3://<silver>/export/           saída de UNLOAD / CTAS (uso manual)
#   Ficam fora de cadunico/ e bolsa-familia-sp/, então o crawler do silver
#   não as cataloga por engano.
# ---------------------------------------------------------------------
locals {
  results_location = "s3://${var.silver_bucket}/${var.results_prefix}/"
  export_location  = "s3://${var.silver_bucket}/${var.export_prefix}/"
}

resource "aws_athena_workgroup" "this" {
  name          = var.workgroup_name
  description   = "Consultas sobre a camada silver do Familia Connect"
  state         = "ENABLED"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = var.bytes_scanned_cutoff

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = local.results_location

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = {
    Name  = var.workgroup_name
    Layer = "silver"
  }
}
