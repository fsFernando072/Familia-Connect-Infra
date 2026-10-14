# ---------------------------------------------------------------------
# Ingestão — Lambda que baixa as bases por ano e grava no bucket bronze
#   familias-cadastro-unico/{ano}/...  (MDS/SAGI)
#   bolsa-familia-sp/{ano}/...         (Prefeitura de SP)
# ---------------------------------------------------------------------
variable "lambda_role_name" {
  type        = string
  default     = "LabRole"
  description = "Nome da IAM Role já existente usada pela Lambda de ingestão"
}

variable "ingestao_ano_inicial" {
  type    = number
  default = 2020
}

variable "ingestao_ano_final" {
  type    = number
  default = 2026
}

variable "ingestao_executar_no_apply" {
  type        = bool
  default     = false
  description = "Se true, executa a carga durante o terraform apply (pode demorar vários minutos)"
}

module "ingestao" {
  source = "./modules/ingestao"

  source_dir        = "${path.module}/lambda/ingestao"
  role_name         = var.lambda_role_name
  bucket_name       = module.storage.bucket_ids["bronze"]
  ano_inicial       = var.ingestao_ano_inicial
  ano_final         = var.ingestao_ano_final
  executar_no_apply = var.ingestao_executar_no_apply
}

output "lambda_ingestao_name" {
  value = module.ingestao.function_name
}

output "lambda_ingestao_invoke_cmd" {
  description = "Comando para rodar a carga manualmente"
  value       = "aws lambda invoke --function-name ${module.ingestao.function_name} --cli-read-timeout 900 --region ${var.aws_region} out.json"
}
