#!/bin/bash
sudo apt update -y

sudo apt install -y awscli nginx

# Buscar IPs das instâncias back dinamicamente
BACK_IPS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ec2-back-*" \
  --query "Reservations[].Instances[].PrivateIpAddress" \
  --output text --region us-east-1)

# Gerar configuração do Nginx com os IPs encontrados
sudo cat > /etc/nginx/sites-available/default <<EOF
upstream backends {
$(for ip in $BACK_IPS; do echo "    server $ip:8080;"; done)
}
server {
    listen 8080;
    location / {
        proxy_pass http://backends;
    }
}
EOF

# Reiniciar Nginx
sudo systemctl reload nginx
