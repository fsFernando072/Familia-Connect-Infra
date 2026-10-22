# 📜 Logs — Fluent Bit → S3 Bronze → Glue + Athena

## O que é coletado (por papel de instância)

| Papel (instâncias) | Fontes | Tag → pasta no S3 |
|---|---|---|
| **todas** | `/var/log/auth.log` (SSH, sudo, SFTP) | `system.auth` → `category=system/source=auth` |
| | `/var/log/syslog` | `system.syslog` |
| | `/var/log/kern.log` | `system.kern` |
| | `/var/log/dpkg.log` | `system.dpkg` |
| | `/var/log/ufw.log` (só existe se o UFW estiver ativo) | `system.ufw` |
| **front, back, ocr** | stdout/stderr dos containers (`/var/lib/docker/containers/*/*-json.log`) | `docker.<serviço>` → `category=docker/source=front\|back\|ocr\|rabbitmq` |
| | journal do `docker.service` | `system.dockerd` |
| **db** | `/var/log/mysql/error.log` | `database.mysql` → `category=database/source=mysql` |

**Nginx:** na arquitetura deste repositório o nginx roda *dentro do container `front`*
(Swarm), não no host; por isso seus access/error logs chegam pelo Docker
(`source=front`) e o access log já sai parseado (`client_ip`, `method`, `path`, `status`,
`bytes`, `referer`, `user_agent`). Spring Boot (`back`), OCR e RabbitMQ seguem o mesmo caminho.
O nome do serviço vem das labels do Swarm, gravadas pelo `/etc/docker/daemon.json`
(`labels-regex`), que o `install.sh` cria; ele também liga rotação (10 MB × 3) dos logs do Docker.

## Estratégia de armazenamento (bucket bronze)

```text
s3://<bronze>/
└── logs/
    ├── category=docker/
    │   ├── source=front/dt=2026-10-07/fc-front-a-201530-<uuid>.json.gz
    │   ├── source=back/dt=2026-10-07/...
    │   ├── source=ocr/dt=2026-10-07/...
    │   └── source=rabbitmq/dt=2026-10-07/...
    ├── category=system/
    │   ├── source=auth/dt=.../   source=syslog/   source=kern/
    │   ├── source=dpkg/          source=ufw/      source=dockerd/
    └── category=database/
        └── source=mysql/dt=.../
```

* **Chave:** `logs/category=<cat>/source=<fonte>/dt=<AAAA-MM-DD>/<hostname>-<HHMMSS>-<uuid>.json.gz`
* **Formato:** JSON lines + gzip (a cada 5 min ou 20 MB). Estilo Hive (`chave=valor`) → o Glue/Athena
  reconhecem as partições `category`, `source` e `dt` direto do caminho.
* **Host no nome do arquivo** (e na coluna `host`): evita colisão entre front-a/front-b e permite filtrar por instância sem multiplicar partições.
* `dt` é a data de **ingestão** (UTC). A hora exata do evento está em `ts`.
* **Schema único** (todas as fontes): `ts, host, role, service, task, stream, message, container_id,
  program, pid, unit, priority` + campos do nginx (`client_ip, remote_user, method, path, status, bytes, referer, user_agent`).
* Mesmo bucket, outras camadas: Parquet em `silver_logs/`, resultados do Athena em `athena-results/`,
  script do Glue em `glue-scripts/` (prefixos diferentes, então funciona mesmo se bronze/silver forem o mesmo bucket).

## Pipeline de consumo (módulo `modules/logs_pipeline`)

```text
EC2 (Fluent Bit) → s3://bronze/logs/ ──► Glue Catalog: logs_bronze   (Athena, tempo quase real)
                         │
                         └─ Glue Job diário 06:00 UTC (dia anterior)
                                   ▼
                        s3://silver/silver_logs/ (Parquet) ──► Glue Catalog: logs_silver
                                                                   ▼
                                           Athena workgroup familia-connect-logs
```

* **Database Glue:** `familia_connect_logs`. Tabelas `logs_bronze` (JSON) e `logs_silver` (Parquet),
  com *partition projection* (`category`, `source`, `dt`): sem crawler, sem `MSCK REPAIR`, partição nova aparece sozinha.
* **Job `familia-connect-logs-bronze-to-silver`** (Glue 4.0, 2× G.1X): lê um dia do bronze, converte `ts` em
  `event_ts`, deriva `level`, `auth_event` (`ssh_failed`/`ssh_accepted`/`sudo_command`) e `src_ip`, e grava Parquet.
  Idempotente (sobrescreve só as partições do dia). Reprocessar:
  `aws glue start-job-run --job-name familia-connect-logs-bronze-to-silver --arguments '--process_date=2026-10-05'`
* **Athena:** workgroup `familia-connect-logs` (limite de 10 GB por consulta) com 6 queries salvas (`logs-01…06`).
* **Sempre filtre por `dt`** (e `source`): é o que limita o custo. Hoje só existe no bronze; o silver recebe o dia na manhã seguinte.

```sql
-- exemplo: 5xx do nginx hoje (bronze)
SELECT ts, host, method, path, status FROM familia_connect_logs.logs_bronze
WHERE dt = cast(current_date AS varchar) AND source = 'front' AND status >= 500 ORDER BY ts DESC LIMIT 50;
```
* Fonte nova no Fluent Bit ⇒ acrescente o nome em `log_sources` (`modules/logs_pipeline/variables.tf`).

## Como aplicar

1. **Ambiente novo / recriável:** `terraform apply`. O Fluent Bit é instalado no boot de cada EC2
   (`scripts/fluentbit_setup.sh.tftpl` embute a configuração no `user_data`, gzip). Log da etapa: `/var/log/fluent-bit-setup.log`.
   ⚠️ Como o `user_data` muda e o módulo `compute` usa `user_data_replace_on_change = true`,
   **o apply recria todas as EC2** (inclusive o banco, que reexecuta o `schema.sql`).
2. **Instâncias já rodando:** copie a pasta `fluent-bit/` e rode (via bastion):
   `sudo bash install.sh <front|back|ocr|db|bastion> <hostname> <bucket-bronze> us-east-1 .`
   Nos nós Docker, depois reinicie o docker e recrie os serviços (`docker service update --force familia-connect_<svc>`) para as labels entrarem nos logs.
   (Ainda assim rode o `terraform apply` só quando puder recriar as EC2, ou aplique apenas `-target=module.logs_pipeline`.)

## Testar

```bash
sudo /opt/fluent-bit/bin/fluent-bit -c /etc/fluent-bit/fluent-bit.conf --dry-run
sudo journalctl -u fluent-bit -f
aws s3 ls s3://<bronze>/logs/ --recursive | tail          # arquivos aparecem ~5 min após os logs
curl -s localhost/ >/dev/null   # (no front) gera access log do nginx
```
