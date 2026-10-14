variable "function_name" {
  type        = string
  default     = "familia-connect-ingestao-bronze"
  description = "Nome da função Lambda de ingestão"
}

variable "source_dir" {
  type        = string
  description = "Pasta com o código Python da Lambda (lambda_function.py)"
}

variable "role_name" {
  type        = string
  description = "Nome de uma IAM Role já existente (ex: LabRole) com permissão de escrita no bucket e de logs"
}

variable "bucket_name" {
  type        = string
  description = "Bucket de destino (camada bronze)"
}

variable "ano_inicial" {
  type    = number
  default = 2020
}

variable "ano_final" {
  type    = number
  default = null
}

variable "executar_no_apply" {
  type        = bool
  default     = false
  description = "Se true, invoca a Lambda durante o terraform apply (síncrono, pode levar vários minutos)"
}
