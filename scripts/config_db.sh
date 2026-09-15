#!/bin/bash
apt update -y
apt install -y mysql-server

cd /home/ubuntu
git clone https://github.com/fsFernando072/Familia-Connect-BD.git

systemctl enable mysql
systemctl start mysql

mysql < /home/ubuntu/Familia-Connect-BD/schema.sql
