#!/bin/bash
apt update -y
apt install -y nginx awscli

# Criar HTML estilizado com link para o Swagger
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Maquina: $(hostname -f)</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: rgb(73, 73, 155);
            color: #fff;
            text-align: center;
            padding-top: 100px;
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 30px;
        }
        a {
            font-size: 1.2em;
            color: #ffeb3b;
            text-decoration: none;
            background: rgba(0,0,0,0.4);
            padding: 10px 20px;
            border-radius: 8px;
            transition: 0.3s;
        }
        a:hover {
            background: rgba(0,0,0,0.7);
        }
    </style>
</head>
<body>
    <h1>Maquina com IP: $(hostname -f)</h1>
</body>
</html>
EOF
