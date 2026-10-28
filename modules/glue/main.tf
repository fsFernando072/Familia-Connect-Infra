data "aws_iam_role" "glue" {
  name = var.role_name
}

# Script PySpark publicado no bucket silver
resource "aws_s3_object" "script" {
  bucket = var.silver_bucket
  key    = "glue-scripts/transformacao_silver.py"
  source = var.script_path
  etag   = filemd5(var.script_path)
}

resource "aws_glue_job" "bronze_para_silver" {
  name        = var.job_name
  description = "Trata nulos e tipos e junta os anos das duas bases: bronze -> silver (Parquet)"
  role_arn    = data.aws_iam_role.glue.arn

  glue_version      = "4.0"
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = 60
  max_retries       = 0

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.silver_bucket}/${aws_s3_object.script.key}"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--BRONZE_BUCKET"                    = var.bronze_bucket
    "--SILVER_BUCKET"                    = var.silver_bucket
    "--TempDir"                          = "s3://${var.silver_bucket}/glue-temp/"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
  }

  tags = {
    Name  = var.job_name
    Layer = "silver"
  }
}

resource "aws_glue_trigger" "mensal" {
  count    = var.schedule == "" ? 0 : 1
  name     = "${var.job_name}-mensal"
  type     = "SCHEDULED"
  schedule = var.schedule
  enabled  = true

  actions {
    job_name = aws_glue_job.bronze_para_silver.name
  }
}
