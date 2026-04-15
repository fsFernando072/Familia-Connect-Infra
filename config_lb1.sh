#!/bin/bash
sudo apt update -y

sudo apt install -y awscli nginx

# Buscar IPs das instâncias front dinamicamente
FRONT_IPS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ec2-front-*" \
  --query "Reservations[].Instances[].PrivateIpAddress" \
  --output text --region us-east-1)

# Gerar configuração do Nginx com os IPs encontrados
sudo cat > /etc/nginx/sites-available/default <<EOF
upstream frontends {
$(for ip in $FRONT_IPS; do echo "    server $ip;"; done)
}
server {
    listen 80;
    location / {
        proxy_pass http://frontends;
    }
}
EOF

# Reiniciar Nginx
sudo systemctl reload nginx
