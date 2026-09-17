data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------------------
# Rede — arquitetura alinhada ao diagrama
# ---------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_a_cidr = var.public_subnet_a_cidr
  public_subnet_b_cidr = var.public_subnet_b_cidr
  front_subnet_a_cidr  = var.front_subnet_a_cidr
  front_subnet_b_cidr  = var.front_subnet_b_cidr
  back_subnet_a_cidr   = var.back_subnet_a_cidr
  back_subnet_b_cidr   = var.back_subnet_b_cidr
  db_subnet_a_cidr     = var.db_subnet_a_cidr
  azs                  = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "keypair" {
  source   = "./modules/keypair"
  key_name = var.key_pair_name
}

module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
}

# ---------------------------------------------------------------------
# Docker Swarm — parâmetros de bootstrap
# O primeiro Front é o manager inicial. Os demais nós consultam os
# tokens no SSM. O LabInstanceProfile precisa permitir ssm:GetParameter
# e ssm:PutParameter.
# ---------------------------------------------------------------------
locals {
  api_base_url            = "/api"
  swarm_manager_parameter = "/familia-connect/swarm/manager-token"
  swarm_worker_parameter  = "/familia-connect/swarm/worker-token"
  swarm_manager_ip        = "10.0.3.10"
}

resource "aws_ssm_parameter" "swarm_manager_token" {
  name      = local.swarm_manager_parameter
  type      = "SecureString"
  value     = "bootstrap-pending"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name = "familia-connect-swarm-manager-token"
  }
}

resource "aws_ssm_parameter" "swarm_worker_token" {
  name  = local.swarm_worker_parameter
  type  = "SecureString"
  value = "bootstrap-pending"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name = "familia-connect-swarm-worker-token"
  }
}

# ---------------------------------------------------------------------
# Banco de dados
# ---------------------------------------------------------------------
locals {
  db_user_data = templatefile("${path.module}/scripts/config_db.sh.tftpl", {
    db_username = var.db_username
    db_password = var.db_password
  })
}

module "compute_db" {
  source = "./modules/compute"

  instances = {
    db = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.db_subnet_a_id
      private_ip           = "10.0.7.10"
      security_group_ids   = [module.security.db_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.db_user_data
      name_tag             = "ec2-db"
      associate_eip        = false
    }
  }
}

# ---------------------------------------------------------------------
# Front — 2 managers do Docker Swarm
# Front A inicializa o cluster; Front B entra como manager.
# ---------------------------------------------------------------------
locals {
  front_a_user_data = templatefile("${path.module}/scripts/config_front.sh.tftpl", {
    manager_ip              = local.swarm_manager_ip
    manager_bootstrap       = "true"
    swarm_manager_parameter = local.swarm_manager_parameter
    swarm_worker_parameter  = local.swarm_worker_parameter
    node_hostname           = "fc-front-a"
    stack_yaml              = local.swarm_stack_template
  })

  front_b_user_data = templatefile("${path.module}/scripts/config_front.sh.tftpl", {
    manager_ip              = local.swarm_manager_ip
    manager_bootstrap       = "false"
    swarm_manager_parameter = local.swarm_manager_parameter
    swarm_worker_parameter  = local.swarm_worker_parameter
    node_hostname           = "fc-front-b"
    stack_yaml              = local.swarm_stack_template
  })

  front_instances = {
    front_a = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.front_subnet_a_id
      private_ip           = local.swarm_manager_ip
      security_group_ids   = [module.security.front_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.front_a_user_data
      name_tag             = "ec2-front-A"
      associate_eip        = false
    }

    front_b = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.front_subnet_b_id
      private_ip           = "10.0.4.10"
      security_group_ids   = [module.security.front_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.front_b_user_data
      name_tag             = "ec2-front-B"
      associate_eip        = false
    }
  }
}

module "compute_front" {
  source     = "./modules/compute"
  instances  = local.front_instances
  depends_on = [aws_ssm_parameter.swarm_manager_token, aws_ssm_parameter.swarm_worker_token]
}

# ---------------------------------------------------------------------
# Back — 2 workers do Docker Swarm
# ---------------------------------------------------------------------
locals {
  back_user_data = templatefile("${path.module}/scripts/config_back.sh.tftpl", {
    manager_ip             = local.swarm_manager_ip
    swarm_worker_parameter = local.swarm_worker_parameter
    node_hostname          = "fc-back-a"
  })

  back_user_data_b = templatefile("${path.module}/scripts/config_back.sh.tftpl", {
    manager_ip             = local.swarm_manager_ip
    swarm_worker_parameter = local.swarm_worker_parameter
    node_hostname          = "fc-back-b"
  })
}

module "compute_back" {
  source = "./modules/compute"

  instances = {
    back_a = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.back_subnet_a_id
      private_ip           = "10.0.5.10"
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
      private_ip           = "10.0.6.10"
      security_group_ids   = [module.security.back_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.back_user_data_b
      name_tag             = "ec2-back-B"
      associate_eip        = false
    }
  }

  depends_on = [module.compute_front]
}

# ---------------------------------------------------------------------
# OCR — 2 workers do Docker Swarm
# ---------------------------------------------------------------------
locals {
  ocr_user_data_a = templatefile("${path.module}/scripts/config_ocr.sh.tftpl", {
    manager_ip             = local.swarm_manager_ip
    swarm_worker_parameter = local.swarm_worker_parameter
    node_hostname          = "fc-ocr-a"
  })

  ocr_user_data_b = templatefile("${path.module}/scripts/config_ocr.sh.tftpl", {
    manager_ip             = local.swarm_manager_ip
    swarm_worker_parameter = local.swarm_worker_parameter
    node_hostname          = "fc-ocr-b"
  })
}

module "compute_ocr" {
  source = "./modules/compute"

  instances = {
    ocr_a = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.back_subnet_a_id
      private_ip           = "10.0.5.20"
      security_group_ids   = [module.security.ocr_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.ocr_user_data_a
      name_tag             = "ec2-ocr-A"
      associate_eip        = false
    }

    ocr_b = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.back_subnet_b_id
      private_ip           = "10.0.6.20"
      security_group_ids   = [module.security.ocr_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = local.ocr_user_data_b
      name_tag             = "ec2-ocr-B"
      associate_eip        = false
    }
  }

  depends_on = [module.compute_front]
}

# ---------------------------------------------------------------------
# ALB OCR interno — Back -> ALB OCR -> workers OCR
# O Swarm publica 8000 no host dos dois workers.
# ---------------------------------------------------------------------
module "lb_ocr" {
  source = "./modules/loadbalancer"

  name               = "ocr"
  internal           = true
  vpc_id             = module.network.vpc_id
  subnet_ids         = [module.network.back_subnet_a_id, module.network.back_subnet_b_id]
  security_group_ids = [module.security.ocr_alb_sg_id]
  target_port        = 8000
  listener_port      = 8000
  health_check_path  = "/docs"

  target_instance_ids = {
    ocr_a = module.compute_ocr.instance_ids["ocr_a"]
    ocr_b = module.compute_ocr.instance_ids["ocr_b"]
  }
}

# ---------------------------------------------------------------------
# ALB Back interno — Front -> ALB Back -> workers Back
# ---------------------------------------------------------------------
module "lb_back" {
  source = "./modules/loadbalancer"

  name               = "back"
  internal           = true
  vpc_id             = module.network.vpc_id
  subnet_ids         = [module.network.front_subnet_a_id, module.network.front_subnet_b_id]
  security_group_ids = [module.security.back_alb_sg_id]
  target_port        = 8080
  listener_port      = 8080
  health_check_path  = "/api/actuator/health"

  target_instance_ids = {
    back_a = module.compute_back.instance_ids["back_a"]
    back_b = module.compute_back.instance_ids["back_b"]
  }
}

# ---------------------------------------------------------------------
# Stack do Swarm. O primeiro manager grava este arquivo e faz deploy.
# ---------------------------------------------------------------------
locals {
  swarm_stack_template = templatefile("${path.module}/scripts/swarm-stack.yml.tftpl", {
    db_name               = var.db_name
    db_username           = var.db_username
    db_password           = var.db_password
    db_type_ddl           = var.db_type_ddl
    jwt_secret            = var.jwt_secret
    app_storage_type      = var.app_storage_type
    app_storage_s3_bucket = var.s3_gold_bucket_name
    app_storage_s3_region = var.aws_region
    ocr_space_api_key     = var.ocr_space_api_key
  })
}

# ---------------------------------------------------------------------
# ALB Front público — Internet -> ALB Front -> managers Front
# ---------------------------------------------------------------------
module "lb_front" {
  source = "./modules/loadbalancer"

  name               = "front"
  internal           = false
  vpc_id             = module.network.vpc_id
  subnet_ids         = [module.network.public_subnet_a_id, module.network.public_subnet_b_id]
  security_group_ids = [module.security.front_alb_sg_id]
  target_port        = 80
  listener_port      = 80
  health_check_path  = "/"

  target_instance_ids = {
    front_a = module.compute_front.instance_ids["front_a"]
    front_b = module.compute_front.instance_ids["front_b"]
  }
}

# ---------------------------------------------------------------------
# S3 — Bronze / Silver / Gold
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
# CloudWatch + SNS
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
    ocr_a   = module.compute_ocr.instance_ids["ocr_a"]
    ocr_b   = module.compute_ocr.instance_ids["ocr_b"]
    db      = module.compute_db.instance_ids["db"]
  }

  front_instance_ids = {
    front_a = module.compute_front.instance_ids["front_a"]
    front_b = module.compute_front.instance_ids["front_b"]
  }

  db_instance_id = module.compute_db.instance_ids["db"]

  lb_back_full_name = module.lb_back.lb_full_name
  tg_back_full_name = module.lb_back.tg_full_name

  bucket_names = {
    bronze = var.s3_bronze_bucket_name
    silver = var.s3_silver_bucket_name
    gold   = var.s3_gold_bucket_name
  }
}
