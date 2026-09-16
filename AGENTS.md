# Familia-Connect-Infra — Agent Instructions

## Overview
Terraform-based AWS infrastructure for Familia Connect app. Provisions VPC, EC2 (7 instances across 2 AZs), ALB (external + internal), S3 buckets, CloudWatch monitoring with SNS alerts.

## Key Commands
```bash
# Initialize (first time or after provider changes)
terraform init

# Plan changes
terraform plan -var-file=terraform.tvars

# Apply changes
terraform apply -var-file=terraform.tvars

# Destroy all resources
terraform destroy -var-file=terraform.tvars

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

## Required Prerequisites
- Terraform >= 1.5.0
- AWS CLI configured (`aws configure`) with permissions for VPC, EC2, ELB, S3, CloudWatch, SNS, IAM
- Existing IAM Instance Profile named `LabInstanceProfile` (referenced in `variables.tf:57-61`)
- SSH key pair created and stored in SSM Parameter Store

## Architecture Notes
- **Region**: us-east-1 (hardcoded in `variables.tf:3`)
- **VPC**: 10.0.0.0/20 with 5 subnets across 2 AZs (us-east-1a, us-east-1b)
- **Instances**: 2 front (public, with EIP), 2 back (private), 1 DB (private), 2 OCR (private)
- **User-data scripts**: `scripts/config_front.sh`, `scripts/config_back.sh`, `scripts/config_db.sh`, `scripts/config_ocr.sh.tftpl` — baked into EC2 launch via `file()` in `main.tf`
- **Front instances**: Install Docker, build React app (`docker build -t react-front .`), run via docker-compose
- **Back instances**: Install Docker only (app deployment not automated)
- **OCR instances**: Install Docker, clone `fsFernando072/Familia-Connect-OCR`, build/run container on port 8000, requires `ocr_space_api_key` variable
- **DB instance**: Installs MySQL, clones schema from `fsFernando072/Familia-Connect-BD` repo

## Module Structure
```
modules/
├── network/      # VPC, subnets, IGW, NAT, route tables
├── keypair/      # TLS key pair + SSM parameter for private key
├── security/     # Security groups + network ACLs
├── compute/      # EC2 instances (7) with user-data
├── loadbalancer/ # ALB (front: internet-facing, back: internal)
├── storage/      # 3 S3 buckets (bronze, silver, gold)
└── monitoring/   # CloudWatch alarms, dashboard, SNS topic
```

## Important Variables (in `terraform.tvars` / `variables.tf`)
- `ami_id`: Ubuntu 22.04 x86 (`ami-0c7217cdde317cfec`) — region-specific, update for other regions
- `iam_instance_profile_name`: Must exist in AWS account before apply
- `alert_emails`: List of emails for SNS notifications
- `ocr_space_api_key`: Required for OCR instances (passed via template in `config_ocr.sh.tftpl`)

## Gotchas
- **No CI/CD** — apply runs locally or manually
- **State file** not committed (`.gitignore` excludes `*.tfstate*`)
- **SSH private key** stored in SSM Parameter Store (output `key_pair_ssm_parameter`)
- **Instance profile** `LabInstanceProfile` must grant S3/SSM/CloudWatch permissions for user-data scripts to work
- **Front user-data** assumes React app source is present in instance (docker build context `.`) — may fail if repo not cloned
- **DB user-data** clones schema from public GitHub repo — requires internet access from private subnet (via NAT)
- **OCR instances** require `ocr_space_api_key` variable to be set (not in current `terraform.tvars`)
- **terraform.tvars is committed** but `.gitignore` excludes `*.tfvars` — potential secret leak risk
- **README.md describes shell scripts** but implementation is Terraform — README is outdated

## Outputs
Key outputs: VPC/subnet IDs, instance IDs, ALB DNS names, S3 bucket names, SNS topic ARN.