variable "silver_bucket" {
  type        = string
  description = "Bucket silver (onde ficam os Parquets do Glue, os resultados do Athena e os exports)"
}

variable "database_name" {
  type        = string
  description = "Banco do Glue Data Catalog consultado pelo Athena (criado pelo crawler do módulo glue)"
}

variable "workgroup_name" {
  type        = string
  default     = "familia-connect-silver"
  description = "Nome do workgroup do Athena"
}

variable "results_prefix" {
  type        = string
  default     = "athena-results"
  description = "Pasta no bucket silver onde o Athena grava o resultado (CSV) de cada consulta"
}

variable "export_prefix" {
  type        = string
  default     = "export"
  description = "Pasta no bucket silver para exports diretos (UNLOAD / CTAS)"
}

variable "bytes_scanned_cutoff" {
  type        = number
  default     = 10737418240 # 10 GB
  description = "Limite de bytes lidos por consulta (trava de custo). Mínimo aceito pela AWS: 10485760 (10 MB)"
}
