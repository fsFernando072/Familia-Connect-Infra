#!/bin/bash
apt update -y

apt install -y nginx

echo "<h1>Máquina com ip: $(hostname -f)</h1>" > /var/www/html/index.html