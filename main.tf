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
# Instâncias EC2
#
# É AQUI que cada instância aponta para o seu script de configuração:
#   - front_a / front_b -> scripts/config_front.sh
#   - back_a  / back_b  -> scripts/config_back.sh
#   - db               -> scripts/config_db.sh
# ---------------------------------------------------------------------
locals {
  instances = {
    front_a = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.public_subnet_a_id
      security_group_ids   = [module.security.front_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = file("${path.module}/scripts/config_front.sh")
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
      user_data            = file("${path.module}/scripts/config_front.sh")
      name_tag             = "ec2-front-B"
      associate_eip        = true
    }
    back_a = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.back_subnet_a_id
      security_group_ids   = [module.security.back_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = file("${path.module}/scripts/config_back.sh")
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
      user_data            = file("${path.module}/scripts/config_back.sh")
      name_tag             = "ec2-back-B"
      associate_eip        = false
    }
    db = {
      ami_id               = var.ami_id
      instance_type        = var.instance_type
      key_name             = module.keypair.key_name
      subnet_id            = module.network.db_subnet_a_id
      security_group_ids   = [module.security.db_sg_id]
      iam_instance_profile = var.iam_instance_profile_name
      user_data            = file("${path.module}/scripts/config_db.sh")
      name_tag             = "ec2-db"
      associate_eip        = false
    }
  }
}

module "compute" {
  source = "./modules/compute"

  instances = local.instances
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
    front_a = module.compute.instance_ids["front_a"]
    front_b = module.compute.instance_ids["front_b"]
  }
}

# ---------------------------------------------------------------------
# Load Balancer BACK (interno) — distribui para back_a/back_b
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
    back_a = module.compute.instance_ids["back_a"]
    back_b = module.compute.instance_ids["back_b"]
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
    front_a = module.compute.instance_ids["front_a"]
    front_b = module.compute.instance_ids["front_b"]
    back_a  = module.compute.instance_ids["back_a"]
    back_b  = module.compute.instance_ids["back_b"]
    db      = module.compute.instance_ids["db"]
  }

  front_instance_ids = {
    front_a = module.compute.instance_ids["front_a"]
    front_b = module.compute.instance_ids["front_b"]
  }

  db_instance_id = module.compute.instance_ids["db"]

  lb_back_full_name = module.lb_back.lb_full_name
  tg_back_full_name = module.lb_back.tg_full_name

  bucket_names = {
    bronze = var.s3_bronze_bucket_name
    silver = var.s3_silver_bucket_name
    gold   = var.s3_gold_bucket_name
  }
}
