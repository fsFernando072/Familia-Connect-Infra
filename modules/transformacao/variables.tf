variable "function_name" {
  type        = string
  default     = "familia-connect-transformacao-athena"
  description = "Nome da função Lambda que executa as transformações no Athena"
}

variable "source_dir" {
  type        = string
  description = "Pasta com lambda_function.py e a subpasta sql/"
}

variable "role_name" {
  type        = string
  description = "IAM Role existente (ex: LabRole) com acesso a Athena, Glue, S3 e logs"
}

variable "database_name" {
  type        = string
  default     = "familia_connect"
  description = "Banco no Glue Data Catalog (apenas letras minúsculas, números e _)"
}

variable "workgroup_name" {
  type    = string
  default = "familia-connect"
}

variable "bronze_bucket" {
  type = string
}

variable "silver_bucket" {
  type        = string
  description = "Também recebe os resultados das consultas em athena-results/"
}

variable "gold_bucket" {
  type = string
}

variable "executar_no_apply" {
  type        = bool
  default     = false
  description = "Se true, executa as transformações durante o terraform apply (exige dados no bronze)"
}

variable "depende_de" {
  type        = any
  default     = null
  description = "Valor qualquer usado só para ordenar a execução após outro módulo (ex: ingestão)"
}
