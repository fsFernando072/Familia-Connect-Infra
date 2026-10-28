variable "job_name" {
  type        = string
  default     = "familia-connect-bronze-para-silver"
  description = "Nome do job Glue de tratamento bronze -> silver"
}

variable "script_path" {
  type        = string
  description = "Caminho local do script PySpark do job"
}

variable "role_name" {
  type        = string
  description = "IAM Role existente (ex: LabRole) assumível pelo Glue, com acesso de leitura ao bronze e escrita ao silver"
}

variable "bronze_bucket" {
  type = string
}

variable "silver_bucket" {
  type = string
}

variable "number_of_workers" {
  type    = number
  default = 2
}

variable "worker_type" {
  type    = string
  default = "G.1X"
}

variable "schedule" {
  type        = string
  default     = "cron(0 7 1 * ? *)"
  description = "Agendamento do job (padrão: dia 1 às 07:00 UTC, 1h depois da ingestão). Vazio = sem agendamento"
}

variable "enable_crawler" {
  type        = bool
  default     = true
  description = "Cria o banco no Data Catalog e o crawler do silver (executado após o job)"
}

variable "database_name" {
  type        = string
  default     = "familia_connect_silver"
  description = "Banco do Glue Data Catalog onde o crawler cria as tabelas"
}

variable "crawler_name" {
  type        = string
  default     = "familia-connect-silver-crawler"
  description = "Nome do crawler do silver"
}

variable "table_prefix" {
  type        = string
  default     = ""
  description = "Prefixo opcional das tabelas criadas (ex: silver_). Vazio = tabelas 'cadunico' e 'bolsa_familia_sp'"
}
