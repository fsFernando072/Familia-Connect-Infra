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

variable "ocr_space_api_key" {
  type        = string
  description = "API key do OCR.space para as instâncias OCR"
}

# ---------------------------------------------------------------------
# Banco de dados (consumidas pela instância db e pelo backend)
# ---------------------------------------------------------------------
variable "db_name" {
  type        = string
  default     = "familia_connect"
  description = "Nome do schema/banco usado no DB_URL do backend"
}

variable "db_username" {
  type        = string
  description = "Usuário MySQL criado na instância db e usado pelo backend para se conectar (DB_USERNAME)"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "Senha MySQL criada na instância db e usada pelo backend para se conectar (DB_PASSWORD)"
  sensitive   = true
}

variable "db_type_ddl" {
  type        = string
  default     = "update"
  description = "Estratégia do Hibernate para o schema (create, create-drop, update, validate) — DB_TYPE_DDL do backend"
}

# ---------------------------------------------------------------------
# Backend
# ---------------------------------------------------------------------
variable "jwt_secret" {
  type        = string
  description = "Chave secreta (mínimo 32 caracteres) usada pelo backend para assinar os tokens JWT (JWT_SECRET)"
  sensitive   = true
}

variable "app_storage_type" {
  type        = string
  default     = "s3"
  description = "Estratégia de armazenamento de arquivos do backend: local ou s3 (APP_STORAGE_TYPE)"
}
