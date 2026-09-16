# ☁️ Família Connect — Infraestrutura AWS (Terraform)

> Infraestrutura como código para o sistema Família Connect, provisionada com Terraform na AWS com alta disponibilidade em múltiplas zonas de disponibilidade.

---

## 📋 Sobre o Projeto

Este repositório contém a configuração Terraform que provisiona toda a infraestrutura AWS do **Família Connect** de forma automatizada. A infraestrutura foi projetada com foco em **alta disponibilidade**, **segurança em camadas** e **observabilidade**, distribuindo os serviços em duas Availability Zones (A e B) dentro de uma VPC dedicada.

---

## 🗺️ Diagrama da Infraestrutura

![Infraestrutura em Nuvem](./diagrama-infraestrutura.jpg)

---

## 🏗️ Visão Geral da Arquitetura

A infraestrutura é organizada em três camadas de sub-redes dentro de uma VPC (`10.0.0.0/20`) na região `us-east-1`:

| Camada | Sub-rede | Zona | CIDR | Descrição |
|---|---|---|---|---|
| Pública | sub-rede-publica-A | us-east-1a | 10.0.1.0/24 | Front-end A + NAT Gateway |
| Pública | sub-rede-publica-B | us-east-1b | 10.0.2.0/24 | Front-end B |
| Privada (Back) | sub-rede-back-A | us-east-1a | 10.0.3.0/24 | Back-end A + OCR A |
| Privada (Back) | sub-rede-back-B | us-east-1b | 10.0.4.0/24 | Back-end B + OCR B |
| Privada (DB) | sub-rede-db-A | us-east-1a | 10.0.5.0/24 | Banco de Dados |

### Roteamento

**Public Route Table** — usada pelas sub-redes públicas:
| Destination | Target |
|---|---|
| 10.0.0.0/20 | local |
| 0.0.0.0/0 | igw-id |

**Private Route Table** — usada pelas sub-redes privadas de back-end e banco:
| Destination | Target |
|---|---|
| 10.0.0.0/20 | local |
| 0.0.0.0/0 | natgw-id |

---

## 🛠️ Serviços AWS Utilizados

| Serviço | Finalidade |
|---|---|
| **VPC** | Rede virtual isolada (`10.0.0.0/20`) |
| **EC2 (t3.micro)** | 7 instâncias: 2 Front-end, 2 Back-end, 1 Banco de Dados, 2 OCR |
| **Internet Gateway** | Acesso à internet para sub-redes públicas |
| **NAT Gateway** | Saída à internet para sub-redes privadas |
| **Application Load Balancer** | LB externo (Front) e interno (Back) |
| **ACL de Rede** | Controle de tráfego por camada (pública, back, DB) |
| **Security Groups** | Firewall por instância (front-sg, back-sg, db-sg) |
| **S3** | 3 buckets de armazenamento: Bronze, Silver e Gold |
| **CloudWatch** | Alarmes de CPU, rede, disco, LB e S3 |
| **SNS** | Notificações por e-mail dos alarmes CloudWatch |
| **Elastic IP** | IPs fixos para instâncias Front-end públicas |
| **SSM Parameter Store** | Armazenamento seguro da chave SSH privada |

---

## 📁 Estrutura do Repositório

```
Familia-Connect-Infra/
├── main.tf                 # Arquivo principal - orquestra todos os módulos
├── variables.tf            # Variáveis de entrada
├── terraform.tvars         # Valores das variáveis (commitado - atenção a segredos)
├── outputs.tf              # Outputs da infraestrutura
├── providers.tf            # Configuração de providers (AWS, TLS)
├── scripts/
│   ├── config_front.sh     # User-data: Front-end (Docker + React build)
│   ├── config_back.sh      # User-data: Back-end (Docker apenas)
│   ├── config_db.sh        # User-data: DB (MySQL + schema do GitHub)
│   └── config_ocr.sh.tftpl # User-data template: OCR (Docker + API key)
├── modules/
│   ├── network/            # VPC, subnets, IGW, NAT, route tables
│   ├── keypair/            # TLS key pair + SSM parameter
│   ├── security/           # Security groups + network ACLs
│   ├── compute/            # EC2 instances (7) with user-data
│   ├── loadbalancer/       # ALB (front: internet-facing, back: internal)
│   ├── storage/            # 3 S3 buckets (bronze, silver, gold)
│   └── monitoring/         # CloudWatch alarms, dashboard, SNS topic
├── diagrama-infraestrutura.jpg
├── .gitignore
└── AGENTS.md               # Instruções para agentes de IA
```

---

## 📊 Monitoramento

O CloudWatch Dashboard `familia-connect-dashboard` monitora em tempo real:

- **CPU de todas as instâncias EC2** (alarme em > 80% por 2 períodos de 5 min)
- **Tráfego de rede (NetworkIn/Out)** das instâncias Front-end (alarme em > 100 MB)
- **Tempo de resposta** do Load Balancer do Back-end (alarme em > 2s)
- **Hosts saudáveis** no Target Group do Back-end (alarme se ≤ 1)
- **Uso de disco** da instância de Banco de Dados (alarme em > 85%)
- **Tamanho dos buckets S3** Bronze, Silver e Gold (alarme em > 5 GB)

Todos os alarmes enviam notificações via **SNS** para os e-mails cadastrados da equipe.

---

## ⚙️ Pré-requisitos

Antes de executar, certifique-se de ter:

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) instalado e configurado (`aws configure`)
- Permissões IAM suficientes para criar VPC, EC2, ELB, S3, CloudWatch, SNS, IAM
- **IAM Instance Profile** chamado `LabInstanceProfile` já existente na conta (concede permissões S3/SSM/CloudWatch para user-data scripts)
- Chave de acesso AWS ativa no ambiente

---

## 🚀 Como Provisionar a Infraestrutura

### 1. Clone o repositório

```bash
git clone https://github.com/fsFernando072/Familia-Connect-Infra.git
cd Familia-Connect-Infra
```

### 2. Configure as variáveis (se necessário)

Edite `terraform.tvars` ou crie um arquivo `.tfvars` próprio com seus valores.

**Variáveis importantes:**
- `ami_id`: AMI Ubuntu 22.04 x86 (padrão: `ami-0c7217cdde317cfec` para us-east-1)
- `iam_instance_profile_name`: Deve existir na conta AWS (padrão: `LabInstanceProfile`)
- `alert_emails`: Lista de e-mails para notificações SNS
- `ocr_space_api_key`: **Obrigatório** para instâncias OCR (não está no terraform.tvars atual)

### 3. Inicialize o Terraform

```bash
terraform init
```

### 4. Planeje as mudanças

```bash
terraform plan -var-file=terraform.tvars
```

### 5. Aplique a infraestrutura

```bash
terraform apply -var-file=terraform.tvars
```

O Terraform irá provisionar, na ordem:
1. Par de chaves TLS + armazenamento da chave privada no SSM Parameter Store
2. VPC e sub-redes (pública A/B, back A/B, DB A)
3. Internet Gateway, NAT Gateway e Route Tables
4. Network ACLs (pública, back, DB)
5. Security Groups (front-sg, back-sg, db-sg)
6. 7 Instâncias EC2 com user-data scripts apropriados
7. Elastic IPs para instâncias Front-end públicas
8. Load Balancers (externo para front na porta 80, interno para back na porta 8080)
9. 3 Buckets S3 (Bronze, Silver, Gold)
10. Tópico SNS + inscrições de e-mail
11. Alarmes CloudWatch + Dashboard

---

## 🗑️ Como Destruir a Infraestrutura

Para remover todos os recursos provisionados e evitar cobranças:

```bash
terraform destroy -var-file=terraform.tvars
```

> ⚠️ **Atenção:** essa operação é irreversível. Todos os dados nas instâncias e buckets S3 serão perdidos.

---

## 🔒 Regras de Segurança

### Security Groups

| SG | Porta | Origem | Finalidade |
|---|---|---|---|
| front-sg | 22, 80, 443, 8080, 3333 | 0.0.0.0/0 | Acesso público ao Front |
| back-sg | 22, 443 | 0.0.0.0/0 | Gerenciamento |
| back-sg | 8080 | front-sg | Comunicação Front → Back |
| back-sg | 8000 | front-sg | Comunicação Front → OCR |
| db-sg | 22 | 0.0.0.0/0 | Gerenciamento |
| db-sg | 3306 | back-sg | Acesso MySQL do Back |

---

## ⚠️ Observações Importantes

- **Sem CI/CD** — apply roda localmente ou manualmente
- **State file** não é commitado (`.gitignore` exclui `*.tfstate*`)
- **Chave SSH privada** fica no SSM Parameter Store (output `key_pair_ssm_parameter`)
- **Perfil de instância** `LabInstanceProfile` deve conceder permissões S3/SSM/CloudWatch para os scripts de user-data funcionarem
- **Front user-data** assume que o código React está presente na instância (docker build context `.`) — pode falhar se o repo não for clonado
- **DB user-data** clona schema de repo público no GitHub — requer acesso à internet da sub-rede privada (via NAT)
- **OCR instances** requerem variável `ocr_space_api_key` (não está no `terraform.tvars` atual)
- **terraform.tvars está commitado** mas `.gitignore` exclui `*.tfvars` — risco de vazamento de segredos
- **README anterior descrevia shell scripts** mas a implementação atual é Terraform

---

## 📄 Licença

Este projeto está sob a licença MIT. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.