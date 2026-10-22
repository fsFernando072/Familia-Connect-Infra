# ---------------------------------------------------------------------
# Pipeline dedicado aos logs:
#   Fluent Bit -> s3://bronze/logs/ (JSON.gz)
#     -> Glue Catalog: logs_bronze (partition projection, consulta imediata)
#     -> Glue Job (diário): bronze -> s3://silver/silver_logs/ (Parquet)
#     -> Glue Catalog: logs_silver
#     -> Athena workgroup dedicado (+ queries salvas)
# Sem Crawler: o schema é fixo (padronizado pelo Fluent Bit) e as
# partições são projetadas, então não há MSCK/crawler para manter.
# ---------------------------------------------------------------------

locals {
  bronze_location = "s3://${var.bronze_bucket}/logs/"
  silver_location = "s3://${var.silver_bucket}/silver_logs/"

  # Parâmetros de partition projection (idênticos nas duas tabelas)
  projection_params = {
    "projection.enabled"          = "true"
    "projection.category.type"    = "enum"
    "projection.category.values"  = join(",", var.log_categories)
    "projection.source.type"      = "enum"
    "projection.source.values"    = join(",", var.log_sources)
    "projection.dt.type"          = "date"
    "projection.dt.format"        = "yyyy-MM-dd"
    "projection.dt.range"         = "${var.projection_start_date},NOW"
    "projection.dt.interval"      = "1"
    "projection.dt.interval.unit" = "DAYS"
  }
}

data "aws_iam_role" "glue" {
  name = var.glue_role_name
}

resource "aws_glue_catalog_database" "logs" {
  name        = var.database_name
  description = "Logs da Família Connect (bronze JSON / silver Parquet)"
}

# ---------------------------------------------------------------------
# Tabela BRONZE — JSON lines gzip, exatamente como o Fluent Bit grava
# ---------------------------------------------------------------------
resource "aws_glue_catalog_table" "logs_bronze" {
  name          = "logs_bronze"
  database_name = aws_glue_catalog_database.logs.name
  table_type    = "EXTERNAL_TABLE"
  description   = "Logs brutos (Fluent Bit). Sempre filtre por dt (e source) para limitar o custo."

  parameters = merge(local.projection_params, {
    EXTERNAL                   = "TRUE"
    classification             = "json"
    compressionType            = "gzip"
    "storage.location.template" = "${local.bronze_location}category=$${category}/source=$${source}/dt=$${dt}"
  })

  partition_keys {
    name = "category"
    type = "string"
  }
  partition_keys {
    name = "source"
    type = "string"
  }
  partition_keys {
    name = "dt"
    type = "string"
  }

  storage_descriptor {
    location      = local.bronze_location
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "ignore.malformed.json" = "true"
      }
    }

    columns {
      name = "ts"
      type = "string"
    }
    columns {
      name = "host"
      type = "string"
    }
    columns {
      name = "role"
      type = "string"
    }
    columns {
      name = "service"
      type = "string"
    }
    columns {
      name = "task"
      type = "string"
    }
    columns {
      name = "stream"
      type = "string"
    }
    columns {
      name = "message"
      type = "string"
    }
    columns {
      name = "container_id"
      type = "string"
    }
    columns {
      name = "program"
      type = "string"
    }
    columns {
      name = "pid"
      type = "string"
    }
    columns {
      name = "unit"
      type = "string"
    }
    columns {
      name = "priority"
      type = "string"
    }
    columns {
      name = "client_ip"
      type = "string"
    }
    columns {
      name = "remote_user"
      type = "string"
    }
    columns {
      name = "nginx_time"
      type = "string"
    }
    columns {
      name = "method"
      type = "string"
    }
    columns {
      name = "path"
      type = "string"
    }
    columns {
      name = "status"
      type = "int"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "referer"
      type = "string"
    }
    columns {
      name = "user_agent"
      type = "string"
    }
  }
}

# ---------------------------------------------------------------------
# Tabela SILVER — Parquet tipado e enriquecido (level, auth_event, src_ip)
# ---------------------------------------------------------------------
resource "aws_glue_catalog_table" "logs_silver" {
  name          = "logs_silver"
  database_name = aws_glue_catalog_database.logs.name
  table_type    = "EXTERNAL_TABLE"
  description   = "Logs tratados (Parquet). Atualizada diariamente pelo job bronze->silver (dia anterior)."

  parameters = merge(local.projection_params, {
    EXTERNAL                   = "TRUE"
    classification             = "parquet"
    "parquet.compression"      = "SNAPPY"
    "storage.location.template" = "${local.silver_location}category=$${category}/source=$${source}/dt=$${dt}"
  })

  partition_keys {
    name = "category"
    type = "string"
  }
  partition_keys {
    name = "source"
    type = "string"
  }
  partition_keys {
    name = "dt"
    type = "string"
  }

  storage_descriptor {
    location      = local.silver_location
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "event_ts"
      type = "timestamp"
    }
    columns {
      name = "host"
      type = "string"
    }
    columns {
      name = "role"
      type = "string"
    }
    columns {
      name = "service"
      type = "string"
    }
    columns {
      name = "task"
      type = "string"
    }
    columns {
      name = "stream"
      type = "string"
    }
    columns {
      name = "level"
      type = "string"
    }
    columns {
      name = "message"
      type = "string"
    }
    columns {
      name = "container_id"
      type = "string"
    }
    columns {
      name = "program"
      type = "string"
    }
    columns {
      name = "pid"
      type = "string"
    }
    columns {
      name = "unit"
      type = "string"
    }
    columns {
      name = "priority"
      type = "string"
    }
    columns {
      name = "auth_event"
      type = "string"
    }
    columns {
      name = "src_ip"
      type = "string"
    }
    columns {
      name = "remote_user"
      type = "string"
    }
    columns {
      name = "method"
      type = "string"
    }
    columns {
      name = "path"
      type = "string"
    }
    columns {
      name = "status"
      type = "int"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "referer"
      type = "string"
    }
    columns {
      name = "user_agent"
      type = "string"
    }
  }
}

# ---------------------------------------------------------------------
# Glue Job bronze -> silver (diário) + trigger
# ---------------------------------------------------------------------
resource "aws_s3_object" "etl_script" {
  bucket = var.silver_bucket
  key    = "glue-scripts/logs_bronze_to_silver.py"
  source = "${path.module}/glue/logs_bronze_to_silver.py"
  etag   = filemd5("${path.module}/glue/logs_bronze_to_silver.py")
}

resource "aws_glue_job" "bronze_to_silver" {
  name              = "familia-connect-logs-bronze-to-silver"
  role_arn          = data.aws_iam_role.glue.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30
  max_retries       = 1

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.silver_bucket}/${aws_s3_object.etl_script.key}"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--bronze_bucket"                    = var.bronze_bucket
    "--silver_bucket"                    = var.silver_bucket
    "--process_date"                     = "YESTERDAY" # sobrescreva para reprocessar: --process_date 2026-10-05
    "--TempDir"                          = "s3://${var.silver_bucket}/glue-temp/"
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
  }
}

resource "aws_glue_trigger" "daily" {
  name     = "familia-connect-logs-bronze-to-silver-daily"
  type     = "SCHEDULED"
  schedule = var.job_schedule
  enabled  = true

  actions {
    job_name = aws_glue_job.bronze_to_silver.name
  }
}

# ---------------------------------------------------------------------
# Athena — workgroup dedicado aos logs + queries salvas
# ---------------------------------------------------------------------
resource "aws_athena_workgroup" "logs" {
  name          = var.workgroup_name
  description   = "Consultas sobre os logs da Família Connect"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 10737418240 # 10 GB por consulta

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = "s3://${var.silver_bucket}/athena-results/"
    }
  }
}

locals {
  named_queries = {
    "logs-01-erros-ultima-hora-bronze" = <<-SQL
      -- Tempo quase real (bronze): erros HTTP 5xx / ERROR na última hora
      SELECT ts, host, source, service, status, path, message
      FROM logs_bronze
      WHERE dt = cast(current_date AS varchar)
        AND from_iso8601_timestamp(ts) > current_timestamp - interval '1' hour
        AND (status >= 500 OR message LIKE '%ERROR%' OR message LIKE '%[error]%')
      ORDER BY ts DESC
      LIMIT 100
    SQL

    "logs-02-nginx-status-por-dia" = <<-SQL
      -- Requisições nginx por status HTTP nos últimos 7 dias (silver)
      SELECT dt, status, count(*) AS requisicoes
      FROM logs_silver
      WHERE category = 'docker' AND source = 'front' AND status IS NOT NULL
        AND dt >= cast(current_date - interval '7' day AS varchar)
      GROUP BY dt, status
      ORDER BY dt DESC, requisicoes DESC
    SQL

    "logs-03-nginx-top-urls-5xx" = <<-SQL
      -- URLs que mais retornam 5xx nos últimos 7 dias
      SELECT path, status, count(*) AS ocorrencias
      FROM logs_silver
      WHERE category = 'docker' AND source = 'front' AND status >= 500
        AND dt >= cast(current_date - interval '7' day AS varchar)
      GROUP BY path, status
      ORDER BY ocorrencias DESC
      LIMIT 50
    SQL

    "logs-04-ssh-falhas-por-ip" = <<-SQL
      -- Tentativas de login SSH falhas por IP de origem (30 dias)
      SELECT src_ip, host, count(*) AS tentativas, min(event_ts) AS primeira, max(event_ts) AS ultima
      FROM logs_silver
      WHERE category = 'system' AND source = 'auth' AND auth_event = 'ssh_failed'
        AND dt >= cast(current_date - interval '30' day AS varchar)
      GROUP BY src_ip, host
      ORDER BY tentativas DESC
      LIMIT 50
    SQL

    "logs-05-backend-erros-recentes" = <<-SQL
      -- Erros do backend (Spring Boot) nos últimos 3 dias
      SELECT event_ts, host, level, message
      FROM logs_silver
      WHERE category = 'docker' AND source = 'back' AND level IN ('ERROR', 'FATAL')
        AND dt >= cast(current_date - interval '3' day AS varchar)
      ORDER BY event_ts DESC
      LIMIT 200
    SQL

    "logs-06-volume-por-fonte" = <<-SQL
      -- Volume de linhas por fonte e dia (saúde do pipeline de logs)
      SELECT dt, category, source, count(*) AS linhas
      FROM logs_silver
      WHERE dt >= cast(current_date - interval '7' day AS varchar)
      GROUP BY dt, category, source
      ORDER BY dt DESC, linhas DESC
    SQL
  }
}

resource "aws_athena_named_query" "this" {
  for_each = local.named_queries

  name      = each.key
  workgroup = aws_athena_workgroup.logs.id
  database  = aws_glue_catalog_database.logs.name
  query     = each.value
}
