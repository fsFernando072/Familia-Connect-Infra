variable "vpc_name" {
  type        = string
  description = "Nome da VPC"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR da VPC"
}

variable "public_subnet_a_cidr" { type = string }
variable "public_subnet_b_cidr" { type = string }
variable "front_subnet_a_cidr"  { type = string }
variable "front_subnet_b_cidr"  { type = string }
variable "back_subnet_a_cidr"   { type = string }
variable "back_subnet_b_cidr"   { type = string }
variable "db_subnet_a_cidr"     { type = string }

variable "azs" {
  type        = list(string)
  description = "Availability Zones a usar (índice 0 e 1)"
}
