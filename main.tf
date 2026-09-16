data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------
# Rede
# ---------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  vpc_name              = var.vpc_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_a_cidr  = var.public_subnet_a_cidr
  public_subnet_b_cidr  = var.public_subnet_b_cidr
  back_subnet_a_cidr    = var.back_subnet_a_cidr
  back_subnet_b_cidr    = var.back_subnet_b_cidr
  db_subnet_a_cidr      = var.db_subnet_a_cidr
  azs                   = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ---------------------------------------------------------------------
# Par de chaves
# ---------------------------------------------------------------------
module "keypair" {
  source = "./modules/keypair"

  key_name = var.key_pair_name
}

# ---------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  vpc_id = module.network.vpc_id
}

# ---------------------------------------------------------------------
# Instâncias EC2 — criadas em 3 estágios, na ordem em que uma camada
# precisa do IP PRIVADO (real, atribuído pela AWS em tempo de apply —
# nunca um IP fixo/estático) da camada anterior:
#
#   1) core  -> db, ocr_a, ocr_b   (não dependem de mais ninguém)
#   2) back  -> back_a, back_b     (precisa do private_ip de db e ocr)
#   3) front -> front_a, front_b   (precisa do DNS do ALB interno do back)
#
# Isso evita depender de um IP privado fixo definido "na mão": o valor
# só é conhecido depois que a instância correspondente é criada, e o
# Terraform resolve essa ordem sozinho através dessas referências.
# ---------------------------------------------------------------------

# ---------- Estágio 1: core (db + ocr) --------------------------------
locals {
  instances_core = {
    db = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.db_subnet_a_id
      security_group_ids   = [module.security.db_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data = templatefile("${path.module}/scripts/config_db.sh.tftpl", {
        db_username = var.db_username
        db_password = var.db_password
      })
      name_tag      = "ec2-db"
      associate_eip = false
    }
    ocr_a = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.back_subnet_a_id
      security_group_ids   = [module.security.back_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = templatefile("${path.module}/scripts/config_ocr.sh.tftpl", { ocr_space_api_key = var.ocr_space_api_key })
      name_tag             = "ec2-ocr-A"
      associate_eip        = false
    }
    ocr_b = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.back_subnet_b_id
      security_group_ids   = [module.security.back_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = templatefile("${path.module}/scripts/config_ocr.sh.tftpl", { ocr_space_api_key = var.ocr_space_api_key })
      name_tag             = "ec2-ocr-B"
      associate_eip        = false
    }
  }
}

module "compute_core" {
  source = "./modules/compute"

  instances = local.instances_core
}

# ---------- Estágio 2: back (usa o private_ip real de db/ocr_a) -------
locals {
  # OCR ainda não tem load balancer próprio (só front e back têm ALB),
  # então o backend fala direto com uma instância OCR pelo IP privado
  # dela — sempre o IP dinâmico atribuído pela AWS, nunca fixado.
  db_private_ip  = module.compute_core.private_ips["db"]
  ocr_private_ip = module.compute_core.private_ips["ocr_a"]

  db_url          = "jdbc:mysql://${local.db_private_ip}:3306/${var.db_name}"
  url_ocr_service = "http://${local.ocr_private_ip}:8000"

  back_user_data = templatefile("${path.module}/scripts/config_back.sh.tftpl", {
    db_url                 = local.db_url
    db_username             = var.db_username
    db_password             = var.db_password
    db_type_ddl             = var.db_type_ddl
    jwt_secret              = var.jwt_secret
    url_ocr_service         = local.url_ocr_service
    app_storage_type        = var.app_storage_type
    app_storage_s3_bucket   = var.s3_gold_bucket_name
    app_storage_s3_region   = var.aws_region
  })

  instances_back = {
    back_a = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.back_subnet_a_id
      security_group_ids   = [module.security.back_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.back_user_data
      name_tag             = "ec2-back-A"
      associate_eip        = false
    }
    back_b = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.back_subnet_b_id
      security_group_ids   = [module.security.back_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.back_user_data
      name_tag             = "ec2-back-B"
      associate_eip        = false
    }
  }
}

module "compute_back" {
  source = "./modules/compute"

  instances = local.instances_back
}

# ---------------------------------------------------------------------
# Load Balancer BACK (interno) — distribui para back_a/back_b.
# É criado logo após o estágio 2 pois o front (estágio 3) vai apontar
# para o DNS deste ALB em vez de um IP privado fixo de uma instância
# back específica — assim o front sempre fala com um back saudável.
# ---------------------------------------------------------------------
module "lb_back" {
  source = "./modules/loadbalancer"

  name                = "back"
  internal            = true
  vpc_id              = module.network.vpc_id
  subnet_ids          = [module.network.back_subnet_a_id, module.network.back_subnet_b_id]
  security_group_ids  = [module.security.back_sg_id]
  target_port         = 8080
  listener_port       = 8080
  health_check_path   = "/"
  target_instance_ids = {
    back_a = module.compute_back.instance_ids["back_a"]
    back_b = module.compute_back.instance_ids["back_b"]
  }
}

# ---------- Estágio 3: front (usa o DNS do ALB interno do back) -------
locals {
  api_base_url = "http://${module.lb_back.dns_name}:8080/api"

  front_user_data = templatefile("${path.module}/scripts/config_front.sh.tftpl", {
    api_base_url = local.api_base_url
  })

  instances_front = {
    front_a = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.public_subnet_a_id
      security_group_ids   = [module.security.front_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.front_user_data
      name_tag             = "ec2-front-A"
      associate_eip        = true
    }
    front_b = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.public_subnet_b_id
      security_group_ids   = [module.security.front_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.front_user_data
      name_tag             = "ec2-front-B"
      associate_eip        = true
    }
  }
}

module "compute_front" {
  source = "./modules/compute"

  instances = local.instances_front
}

# ---------------------------------------------------------------------
# Load Balancer FRONT (internet-facing) — distribui para front_a/front_b
# ---------------------------------------------------------------------
module "lb_front" {
  source = "./modules/loadbalancer"

  name                = "front"
  internal            = false
  vpc_id              = module.network.vpc_id
  subnet_ids          = [module.network.public_subnet_a_id, module.network.public_subnet_b_id]
  security_group_ids  = [module.security.front_sg_id]
  target_port         = 80
  listener_port       = 80
  health_check_path   = "/"
  target_instance_ids = {
    front_a = module.compute_front.instance_ids["front_a"]
    front_b = module.compute_front.instance_ids["front_b"]
  }
}

# ---------------------------------------------------------------------
# Buckets S3 (bronze / silver / gold)
# ---------------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  bucket_names = {
    bronze = var.s3_bronze_bucket_name
    silver = var.s3_silver_bucket_name
    gold   = var.s3_gold_bucket_name
  }
}

# ---------------------------------------------------------------------
# SNS + Alarmes CloudWatch + Dashboard
# ---------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  region       = var.aws_region
  alert_emails = var.alert_emails

  cpu_instance_ids = {
    front_a = module.compute_front.instance_ids["front_a"]
    front_b = module.compute_front.instance_ids["front_b"]
    back_a  = module.compute_back.instance_ids["back_a"]
    back_b  = module.compute_back.instance_ids["back_b"]
    db      = module.compute_core.instance_ids["db"]
  }

  front_instance_ids = {
    front_a = module.compute_front.instance_ids["front_a"]
    front_b = module.compute_front.instance_ids["front_b"]
  }

  db_instance_id = module.compute_core.instance_ids["db"]

  lb_back_full_name = module.lb_back.lb_full_name
  tg_back_full_name = module.lb_back.tg_full_name

  bucket_names = {
    bronze = var.s3_bronze_bucket_name
    silver = var.s3_silver_bucket_name
    gold   = var.s3_gold_bucket_name
  }
}
