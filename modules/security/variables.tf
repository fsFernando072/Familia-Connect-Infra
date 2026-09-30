variable "vpc_id" {
  type = string
}

variable "bastion_allowed_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs autorizados a acessar o bastion na porta 22"
}