variable "bronze_bucket" {
  type        = string
  description = "Bucket bronze onde o Fluent Bit grava (prefixo logs/)"
}

variable "silver_bucket" {
  type        = string
  description = "Bucket silver: logs em Parquet (silver_logs/), resultados do Athena e scripts do Glue"
}

variable "database_name" {
  type    = string
  default = "familia_connect_logs"
}

variable "workgroup_name" {
  type    = string
  default = "familia-connect-logs"
}

variable "glue_role_name" {
  type        = string
  default     = "LabRole"
  description = "Role IAM já existente usada pelo job do Glue (precisa ler o bronze e gravar no silver)"
}

variable "job_schedule" {
  type        = string
  default     = "cron(0 6 * * ? *)"
  description = "Agendamento (UTC) do job bronze -> silver. Padrão: todo dia 06:00 UTC (03:00 BRT), processa o dia anterior."
}

variable "projection_start_date" {
  type        = string
  default     = "2026-10-01"
  description = "Primeiro dia (AAAA-MM-DD) projetado nas tabelas. Antes disso o Athena ignora."
}

variable "log_categories" {
  type    = list(string)
  default = ["docker", "system", "database"]
}

variable "log_sources" {
  type        = list(string)
  description = "Valores possíveis de source= (o Athena só enxerga as fontes listadas aqui). Nova fonte no Fluent Bit => adicionar aqui."
  default = [
    "front", "back", "ocr", "rabbitmq", "unknown", # docker.*
    "auth", "syslog", "kern", "dpkg", "ufw", "dockerd", # system.*
    "mysql", # database.*
  ]
}
