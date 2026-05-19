#!/bin/bash

echo "Atualizando pacotes..."
sudo apt update -y
sudo apt upgrade -y

echo "Instalando dependências..."
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "Configurando chave GPG do Docker..."
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "Adicionando repositório Docker..."
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Atualizando repositórios..."
sudo apt update -y

echo "Instalando Docker..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Habilitando e iniciando Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Configurando permissões do Docker..."
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER

echo "Construindo imagem React..."
sudo docker build -t react-front .

echo "Subindo containers com Docker Compose..."
sudo docker compose up -d --build

echo "Criando página HTML..."
sudo mkdir -p /var/www/html

cat <<EOF | sudo tee /var/www/html/index.html > /dev/null
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Máquina: $(hostname -f)</title>

    <style>
        body {
            font-family: Arial, sans-serif;
            background: rgb(73, 73, 155);
            color: #fff;
            text-align: center;
            padding-top: 100px;
            margin: 0;
        }

        h1 {
            font-size: 2.5em;
            margin-bottom: 20px;
        }

        p {
            font-size: 1.2em;
        }

        .card {
            background: rgba(0,0,0,0.3);
            display: inline-block;
            padding: 30px;
            border-radius: 12px;
            box-shadow: 0 0 10px rgba(0,0,0,0.3);
        }
    </style>
</head>

<body>
    <div class="card">
        <h1>Frontend React iniciado</h1>

        <p><strong>Hostname:</strong> $(hostname -f)</p>

        <p><strong>IP:</strong> $(hostname -I | awk '{print $1}')</p>
    </div>
</body>
</html>
EOF

echo "Subiu!"
