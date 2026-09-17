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

A infraestrutura segue o diagrama fornecido, usando duas Availability Zones dentro da VPC `10.0.0.0/20`:

| Camada | AZ A | AZ B | Função |
|---|---|---|---|
| Pública | `10.0.1.0/24` | `10.0.2.0/24` | ALB Front + NAT Gateway |
| Front privada | `10.0.3.0/24` | `10.0.4.0/24` | Front-end A/B |
| Back privada | `10.0.5.0/24` | `10.0.6.0/24` | Back-end A/B + OCR A/B |
| Banco | `10.0.7.0/24` | — | Banco de dados |

### Fluxo de comunicação

```text
Cliente
  │
  ▼
ALB Front (público :80)
  │
  ▼
Front A/B (privados :80)
  │
  ▼
Nginx /api
  │
  ▼
ALB Back (interno :8080)
  │
  ▼
Back A/B (:8080)
  │
  ├──────────────► Banco de dados (:3306)
  │
  └──────────────► ALB OCR (interno :8000)
                         │
                         ▼
                      OCR A/B
```

O Front não possui EIP. O navegador usa `API_BASE_URL=/api`; o Nginx do container encaminha as requisições `/api/*` para o ALB interno do Back. Assim, o ALB Back e as instâncias de Back/OCR permanecem privados.

As sub-redes privadas usam **dois NAT Gateways**, um por AZ, para saída à internet.

### Roteamento

**Sub-redes públicas:** `0.0.0.0/0` → Internet Gateway.

**Sub-redes privadas da AZ A:** `0.0.0.0/0` → NAT Gateway A.

**Sub-redes privadas da AZ B:** `0.0.0.0/0` → NAT Gateway B.


## 🛠️ Serviços AWS Utilizados

| Serviço | Finalidade |
|---|---|
| **VPC** | Rede virtual isolada (`10.0.0.0/20`) |
| **EC2 (t3.micro)** | 7 instâncias: 2 Front managers, 2 Back workers, 1 Banco de Dados, 2 OCR workers |
| **Docker Swarm** | Cluster com 2 managers (Front A/B) e 4 workers (Back A/B + OCR A/B) |
| **Internet Gateway** | Acesso à internet para sub-redes públicas |
| **NAT Gateway** | Saída à internet para sub-redes privadas |
| **Application Load Balancer** | ALB público do Front + ALBs internos do Back e OCR |
| **ACL de Rede** | Controle de tráfego por camada (pública, front, back, DB) |
| **Security Groups** | Firewall por ALB e instância (Front, Back, OCR e DB) |
| **S3** | 3 buckets de armazenamento: Bronze, Silver e Gold |
| **CloudWatch** | Alarmes de CPU, rede, disco, LB e S3 |
| **SNS** | Notificações por e-mail dos alarmes CloudWatch |
| **Elastic IP** | 2 EIPs utilizados pelos NAT Gateways; os Fronts não possuem EIP |
| **SSM Parameter Store** | Armazenamento seguro da chave SSH privada |

---

## 📁 Estrutura do Repositório

```
Familia-Connect-Infra/
├── main.tf                 # Arquivo principal - orquestra todos os módulos
├── variables.tf            # Variáveis de entrada
├── terraform.tfvars.example # Exemplo dos valores das variáveis
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
│   ├── loadbalancer/       # ALB Front público + ALBs internos Back e OCR
│   ├── storage/            # 3 S3 buckets (bronze, silver, gold)
│   └── monitoring/         # CloudWatch alarms, dashboard, SNS topic
├── diagrama-infraestrutura.jpg
├── .gitignore
└── AGENTS.md               # Instruções para agentes de IA
```

---

## 🐳 Docker Swarm

O cluster é inicializado automaticamente pelas instâncias EC2:

| Instância | Papel Swarm | Serviço | Hostname
|---|---|---|---|
| Front A | Manager | Front | `fc-front-a`
| Front B | Manager | Front | `fc-front-b`
| Back A | Worker | Back | `fc-back-a`
| Back B | Worker | Back | `fc-back-b`
| OCR A | Worker | OCR | `fc-ocr-a`
| OCR B | Worker | OCR | `fc-ocr-b`

O Front A executa `docker swarm init`. O token de manager e o token de worker são armazenados temporariamente no AWS Systems Manager Parameter Store para que os demais nós possam entrar no cluster sem deixar tokens fixos no Terraform. O `LabInstanceProfile` precisa permitir `ssm:GetParameter` e `ssm:PutParameter`.

A stack é publicada pelo Front A somente depois que os quatro workers entram no cluster. Labels `fc_role=back` e `fc_role=ocr` garantem que cada serviço rode apenas nos workers correspondentes. Os serviços usam publicação `mode: host`, permitindo que os três ALBs apontem diretamente para os nós corretos.

Portas internas necessárias para o Swarm:
- TCP `2377`: gerenciamento do cluster
- TCP/UDP `7946`: comunicação entre nós
- UDP `4789`: rede overlay

O usuário final continua acessando apenas o ALB Front público.

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
8. Load Balancers (Front público :80, Back interno :8080, OCR interno :8000)
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
| front-sg | 80 | front-alb-sg | ALB Front → Front |
| front-sg | 22 | 0.0.0.0/0 | Administração |
| front-sg | 2377/TCP | VPC | Docker Swarm control plane |
| front-sg | 7946/TCP+UDP | VPC | Comunicação entre nós Swarm |
| front-sg | 4789/UDP | VPC | Rede overlay Swarm |
| back-sg | 8080 | back-alb-sg | ALB Back → Back |
| back-sg | 22 | 0.0.0.0/0 | Administração |
| back-sg | 2377/TCP | VPC | Docker Swarm control plane |
| back-sg | 7946/TCP+UDP | VPC | Comunicação entre nós Swarm |
| back-sg | 4789/UDP | VPC | Rede overlay Swarm |
| ocr-sg | 8000 | ocr-alb-sg | ALB OCR → OCR |
| ocr-sg | 22 | 0.0.0.0/0 | Administração |
| ocr-sg | 2377/TCP | VPC | Docker Swarm control plane |
| ocr-sg | 7946/TCP+UDP | VPC | Comunicação entre nós Swarm |
| ocr-sg | 4789/UDP | VPC | Rede overlay Swarm |
| db-sg | 22 | 0.0.0.0/0 | Administração |
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