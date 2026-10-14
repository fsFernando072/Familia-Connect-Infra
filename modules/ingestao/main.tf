data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.build/${var.function_name}.zip"
  excludes    = ["__pycache__", "*.pyc"]
}

data "aws_iam_role" "lambda" {
  name = var.role_name
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "ingestao" {
  function_name = var.function_name
  description   = "Baixa CSVs por ano (MDS/SAGI e Prefeitura de SP) e grava no bucket bronze"

  role    = data.aws_iam_role.lambda.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.12"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  timeout     = 900
  memory_size = 512

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
      ANO_INICIAL = tostring(var.ano_inicial)
      ANO_FINAL = var.ano_final == null ? "" : tostring(var.ano_final)
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = {
    Name  = var.function_name
    Layer = "bronze"
  }
}

# Execução única opcional durante o apply
resource "aws_lambda_invocation" "primeira_carga" {
  count         = var.executar_no_apply ? 1 : 0
  function_name = aws_lambda_function.ingestao.function_name

  input = jsonencode({
    ano_inicial = var.ano_inicial
    ano_final   = var.ano_final
    bases       = ["base1", "base2"]
  })
}

resource "aws_cloudwatch_event_rule" "mensal" {
  name                = "${var.function_name}-mensal"
  schedule_expression = "cron(0 6 1 * ? *)"
}

resource "aws_cloudwatch_event_target" "mensal" {
  rule      = aws_cloudwatch_event_rule.mensal.name
  target_id = "lambda"
  arn       = aws_lambda_function.ingestao.arn
  input     = jsonencode({ somente_ano_atual = true })
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestao.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.mensal.arn
}