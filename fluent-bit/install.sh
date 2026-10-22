#!/bin/bash
# Instala e configura o Fluent Bit (logs -> S3 bronze).
#
# Uso:  sudo bash install.sh <role> <hostname> <bucket-bronze> <region> [dir-com-os-arquivos]
#   role: front | back | ocr | db | bastion
#   ex.:  sudo bash install.sh back fc-back-a familia-connect-bronze-g02 us-east-1 ./fluent-bit
#
# Idempotente: pode ser executado de novo para atualizar a configuração.

ROLE="$1"; HOST="$2"; BUCKET="$3"; REGION="$4"
SRC="${5:-$(cd "$(dirname "$0")" && pwd)}"
CONF=/etc/fluent-bit

if [ -z "$ROLE" ] || [ -z "$HOST" ] || [ -z "$BUCKET" ] || [ -z "$REGION" ]; then
    echo "uso: $0 <role> <hostname> <bucket> <region> [dir]" >&2
    exit 1
fi

case "$ROLE" in
    front|back|ocr) INPUTS="system docker" ;;
    db)             INPUTS="system mysql" ;;
    bastion)        INPUTS="system" ;;
    *) echo "role inválido: $ROLE" >&2; exit 1 ;;
esac

# --- 1. Docker: labels do Swarm nos logs + rotação (só nós com containers) ---
case " $INPUTS " in *" docker "*)
    mkdir -p /etc/docker
    if [ ! -s /etc/docker/daemon.json ]; then
        cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "labels-regex": "^com\\.docker\\.(swarm\\.(service|task)\\.name|stack\\.namespace)$"
  }
}
JSON
        if systemctl is-active --quiet docker; then
            echo "AVISO: daemon.json criado com o Docker já rodando. Reinicie o docker e recrie os" \
                 "serviços (docker service update --force <svc>) para as labels aparecerem nos logs."
        fi
    else
        echo "AVISO: /etc/docker/daemon.json já existe; confira se tem log-opts labels-regex (ver fluent-bit/install.sh)."
    fi
    ;;
esac

# --- 2. Instala o Fluent Bit (repositório oficial apt) ---
if [ ! -x /opt/fluent-bit/bin/fluent-bit ]; then
    ok=""
    for i in $(seq 1 30); do
        if curl -4 -s -o /dev/null --connect-timeout 5 https://packages.fluentbit.io; then ok=1; break; fi
        echo "Aguardando rede para packages.fluentbit.io ($i/30)..."; sleep 10
    done
    [ -n "$ok" ] || { echo "Sem acesso ao repositório do Fluent Bit." >&2; exit 1; }

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y || true
    apt-get install -y ca-certificates curl gnupg || true
    install -m 0755 -d /usr/share/keyrings
    curl -fsSL https://packages.fluentbit.io/fluentbit.key | gpg --dearmor --yes -o /usr/share/keyrings/fluentbit-keyring.gpg || exit 1
    CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/$CODENAME $CODENAME main" \
        > /etc/apt/sources.list.d/fluent-bit.list
    apt-get update -y
    apt-get install -y fluent-bit || exit 1
fi

# --- 3. Configuração ---
mkdir -p "$CONF/conf.d" /var/lib/fluent-bit/storage /var/lib/fluent-bit/s3
rm -f "$CONF"/conf.d/*.conf
for i in $INPUTS; do cp "$SRC/inputs-$i.conf" "$CONF/conf.d/inputs-$i.conf"; done
cp "$SRC/parsers_familia.conf" "$SRC/familia.lua" "$CONF/"
sed -e "s|__HOST__|$HOST|g" -e "s|__ROLE__|$ROLE|g" \
    -e "s|__BUCKET__|$BUCKET|g" -e "s|__REGION__|$REGION|g" \
    "$SRC/fluent-bit.conf" > "$CONF/fluent-bit.conf"

# --- 4. Valida e sobe ---
if /opt/fluent-bit/bin/fluent-bit -c "$CONF/fluent-bit.conf" --dry-run; then
    systemctl enable fluent-bit
    systemctl restart fluent-bit
    echo "Fluent Bit ativo em $HOST (role=$ROLE) -> s3://$BUCKET/logs/"
else
    echo "Configuração inválida; Fluent Bit NÃO foi (re)iniciado." >&2
    exit 1
fi
