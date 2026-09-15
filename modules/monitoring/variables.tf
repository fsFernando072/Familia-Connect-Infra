variable "sns_topic_name" {
  type    = string
  default = "familia-connect-cloudwatch-alerts"
}

variable "alert_emails" {
  type = list(string)
}

variable "dashboard_name" {
  type    = string
  default = "familia-connect-dashboard"
}

variable "region" {
  type = string
}

variable "cpu_instance_ids" {
  description = "Mapa nome_logico => instance_id para alarme de CPU (todas as instâncias)"
  type        = map(string)
}

variable "front_instance_ids" {
  description = "Mapa nome_logico => instance_id das instâncias FRONT (alarmes de rede)"
  type        = map(string)
}

variable "db_instance_id" {
  type = string
}

variable "lb_back_full_name" {
  type = string
}

variable "tg_back_full_name" {
  type = string
}

variable "bucket_names" {
  description = "Mapa nome_logico (bronze/silver/gold) => nome do bucket"
  type        = map(string)
}
