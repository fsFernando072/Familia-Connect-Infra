data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.build/${var.function_name}.zip"
  excludes    = ["__pycache__", "*.pyc"]
}

data "aws_iam_role" "lambda" {
  name = var.role_name
}

# ---------------------------------------------------------------------
# Glue Data Catalog + Athena
# ---------------------------------------------------------------------
resource "aws_glue_catalog_database" "this" {
  name        = var.database_name
  description = "Tabelas bronze/silver/gold do Família Connect"
}

resource "aws_athena_workgroup" "this" {
  name          = var.workgroup_name
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    # Engine v3 é necessária para tabelas Iceberg (DELETE/INSERT)
    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = "s3://${var.silver_bucket}/athena-results/"
    }
  }
}

# ---------------------------------------------------------------------
# Lambda que executa os SQLs em ordem
# ---------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "transformacao" {
  function_name = var.function_name
  description   = "Executa no Athena o tratamento bronze -> silver -> gold"

  role    = data.aws_iam_role.lambda.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.12"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  timeout     = 900
  memory_size = 256

  environment {
    variables = {
      ATHENA_DATABASE  = aws_glue_catalog_database.this.name
      ATHENA_WORKGROUP = aws_athena_workgroup.this.name
      BRONZE_BUCKET    = var.bronze_bucket
      SILVER_BUCKET    = var.silver_bucket
      GOLD_BUCKET      = var.gold_bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = {
    Name  = var.function_name
    Layer = "silver-gold"
  }
}

# Execução única opcional durante o apply
resource "aws_lambda_invocation" "primeira_transformacao" {
  count         = var.executar_no_apply ? 1 : 0
  function_name = aws_lambda_function.transformacao.function_name
  input         = jsonencode({})

  depends_on = [aws_athena_workgroup.this]
  triggers = {
    depende_de = jsonencode(var.depende_de)
  }
}

# Dia 1 às 07:00 UTC — uma hora depois da ingestão (cron 06:00)
resource "aws_cloudwatch_event_rule" "mensal" {
  name                = "${var.function_name}-mensal"
  schedule_expression = "cron(0 7 1 * ? *)"
}

resource "aws_cloudwatch_event_target" "mensal" {
  rule      = aws_cloudwatch_event_rule.mensal.name
  target_id = "lambda"
  arn       = aws_lambda_function.transformacao.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transformacao.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.mensal.arn
}
