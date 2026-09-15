variable "name" {
  type        = string
  description = "Nome base do ALB / target group (max 32 chars nas do ALB)"
}

variable "internal" {
  type        = bool
  description = "true = interno (back), false = internet-facing (front)"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "target_port" {
  type = number
}

variable "listener_port" {
  type = number
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "target_instance_ids" {
  type        = map(string)
  description = "Mapa nome_logico => instance_id a registrar no target group"
}
