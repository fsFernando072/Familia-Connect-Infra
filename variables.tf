variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  type    = string
  default = "vpc-familia-connect"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/20"
}

variable "public_subnet_a_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "back_subnet_a_cidr" {
  type    = string
  default = "10.0.3.0/24"
}

variable "back_subnet_b_cidr" {
  type    = string
  default = "10.0.4.0/24"
}

variable "db_subnet_a_cidr" {
  type    = string
  default = "10.0.5.0/24"
}

variable "ami_id" {
  type        = string
  default     = "ami-0c7217cdde317cfec"
  description = "Ubuntu Server 22.04 LTS (x86)"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_pair_name" {
  type    = string
  default = "myssh"
}

variable "iam_instance_profile_name" {
  type        = string
  default     = "LabInstanceProfile"
  description = "Nome de um Instance Profile IAM já existente na conta."
}

variable "s3_bronze_bucket_name" {
  type    = string
  default = "familia-connect-bronze-g02"
}

variable "s3_silver_bucket_name" {
  type    = string
  default = "familia-connect-silver-g02"
}

variable "s3_gold_bucket_name" {
  type    = string
  default = "familia-connect-gold-g02"
}

variable "alert_emails" {
  type = list(string)
  default = [
    "anna.maegaki@sptech.school",
    "fernando.fsilva@sptech.school",
    "gabriel.castilho@sptech.school",
    "miguel.ramos@sptech.school",
    "joao.oliveiraneto@sptech.school",
  ]
  description = "Lista de e-mails que receberão os alarmes via SNS."
}
