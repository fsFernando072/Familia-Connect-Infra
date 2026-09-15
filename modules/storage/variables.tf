variable "bucket_names" {
  description = "Mapa nome_logico (bronze/silver/gold) => nome do bucket"
  type        = map(string)
}
