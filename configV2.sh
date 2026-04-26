#!/bin/bash
set -e
set -u

# Variáveis
VPC_NAME="vpc-familia-connect"
CIDR_BLOCK="10.0.0.0/16"
REGION="us-east-1"
AZ_A="${REGION}a"
AZ_B="${REGION}b"
AMI_ID="ami-0c7217cdde317cfec" # Ubuntu Server 22.04 LTS (x86)
INSTANCE_TYPE="t3.micro"
KEY_NAME="myssh"
# sub-redes
SUBNET_PUBLIC_A="10.0.1.0/24"
SUBNET_BACK_A="10.0.2.0/24"
SUBNET_DB_A="10.0.5.0/24"
SUBNET_PUBLIC_B="10.0.3.0/24"
SUBNET_BACK_B="10.0.4.0/24"


# criando par de chaves

aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --query 'KeyMaterial' \
  --output text > $KEY_NAME.pem || true
chmod 400 $KEY_NAME.pem


# criando VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $CIDR_BLOCK \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
  --query 'Vpc.VpcId' \
  --output text \
  --region $REGION)


# sub-redes
SUBNET_PUBLIC_A_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PUBLIC_A --availability-zone $AZ_A --query 'Subnet.SubnetId' --output text --region $REGION)
SUBNET_BACK_A_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_BACK_A --availability-zone $AZ_A --query 'Subnet.SubnetId' --output text --region $REGION)
SUBNET_DB_A_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_DB_A --availability-zone $AZ_A --query 'Subnet.SubnetId' --output text --region $REGION)


SUBNET_PUBLIC_B_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PUBLIC_B --availability-zone $AZ_B --query 'Subnet.SubnetId' --output text --region $REGION)
SUBNET_BACK_B_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_BACK_B --availability-zone $AZ_B --query 'Subnet.SubnetId' --output text --region $REGION)

# Internet Gateway + Route Table
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region $REGION)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION

RTB_PUBLIC=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text --region $REGION)
aws ec2 create-route --route-table-id $RTB_PUBLIC --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION

aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_PUBLIC_A_ID --region $REGION
aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_PUBLIC_B_ID --region $REGION


# Nat Gateway
EIP=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text --region $REGION)

NAT=$(aws ec2 create-nat-gateway \
  --subnet-id $SUBNET_PUBLIC_A_ID \
  --allocation-id $EIP \
  --query 'NatGateway.NatGatewayId' \
  --output text \
  --region $REGION)

aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT --region $REGION

RTB_PRIVATE=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text --region $REGION)

aws ec2 create-route \
  --route-table-id $RTB_PRIVATE \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT \
  --region $REGION

aws ec2 associate-route-table --route-table-id $RTB_PRIVATE --subnet-id $SUBNET_BACK_A_ID --region $REGION
aws ec2 associate-route-table --route-table-id $RTB_PRIVATE --subnet-id $SUBNET_BACK_B_ID --region $REGION

# Criação ACLs
echo -e "\nCriando ACL Pública"
ACL_PUBLIC_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-publica}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text --region $REGION)

# Associar às subnets públicas A e B
ASSOC_ID_PUBLIC_A=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_PUBLIC_A_ID" \
    --query "NetworkAcls[0].Associations[0].NetworkAclAssociationId" \
    --output text --region $REGION)
aws ec2 replace-network-acl-association --association-id $ASSOC_ID_PUBLIC_A --network-acl-id $ACL_PUBLIC_ID --region $REGION

ASSOC_ID_PUBLIC_B=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_PUBLIC_B_ID" \
    --query "NetworkAcls[0].Associations[0].NetworkAclAssociationId" \
    --output text --region $REGION)
aws ec2 replace-network-acl-association --association-id $ASSOC_ID_PUBLIC_B --network-acl-id $ACL_PUBLIC_ID --region $REGION

# Regras de entrada ACL pública
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress --rule-number 100 --protocol tcp --port-range From=22,To=22 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress --rule-number 200 --protocol tcp --port-range From=80,To=80 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress --rule-number 300 --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress --rule-number 400 --protocol tcp --port-range From=8080,To=8080 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress --rule-number 500 --protocol tcp --port-range From=32000,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

# Saída ACL pública
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --egress --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION


echo -e "\nCriando ACL Back A"
ACL_BACK_A_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-back-a}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text --region $REGION)

ASSOC_ID_BACK_A=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_BACK_A_ID" \
    --query "NetworkAcls[0].Associations[0].NetworkAclAssociationId" \
    --output text --region $REGION)
aws ec2 replace-network-acl-association --association-id $ASSOC_ID_BACK_A --network-acl-id $ACL_BACK_A_ID --region $REGION

# Regras de entrada ACL Back A
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_A_ID --ingress --rule-number 100 --protocol tcp --port-range From=8080,To=8080 --cidr-block $SUBNET_PUBLIC_A --rule-action allow --region $REGION
# Saída ACL Back A
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_A_ID --egress --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION


echo -e "\nCriando ACL Back B"
ACL_BACK_B_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-back-b}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text --region $REGION)

ASSOC_ID_BACK_B=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_BACK_B_ID" \
    --query "NetworkAcls[0].Associations[0].NetworkAclAssociationId" \
    --output text --region $REGION)
aws ec2 replace-network-acl-association --association-id $ASSOC_ID_BACK_B --network-acl-id $ACL_BACK_B_ID --region $REGION

# Regras de entrada ACL Back B
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_B_ID --ingress --rule-number 100 --protocol tcp --port-range From=8080,To=8080 --cidr-block $SUBNET_PUBLIC_B --rule-action allow --region $REGION
# Saída ACL Back B
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_B_ID --egress --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION


echo -e "\nCriando ACL Banco"
ACL_DB_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-db}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text --region $REGION)

ASSOC_ID_DB=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_DB_A_ID" \
    --query "NetworkAcls[0].Associations[0].NetworkAclAssociationId" \
    --output text --region $REGION)
aws ec2 replace-network-acl-association --association-id $ASSOC_ID_DB --network-acl-id $ACL_DB_ID --region $REGION

# Regras de entrada ACL Banco
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress --rule-number 100 --protocol tcp --port-range From=3306,To=3306 --cidr-block $SUBNET_BACK_A --rule-action allow --region $REGION
# Saída ACL Banco
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --egress --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION


# Security Groups
SG_FRONT=$(aws ec2 create-security-group --group-name front-sg --description "Front" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)
SG_BACK=$(aws ec2 create-security-group --group-name back-sg --description "Back" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)
SG_DB=$(aws ec2 create-security-group --group-name db-sg --description "Banco" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)



aws ec2 authorize-security-group-ingress --group-id $SG_FRONT --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_DB --protocol tcp --port 3306 --source-group $SG_BACK --region $REGION

aws ec2 authorize-security-group-ingress --group-id $SG_BACK --protocol tcp --port 8080 --source-group $SG_FRONT --region $REGION


# Inastâncias
FRONT1=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --network-interfaces "AssociatePublicIpAddress=true,DeviceIndex=0,SubnetId=$SUBNET_PUBLIC_A_ID,Groups=$SG_FRONT" \
  --user-data "$(cat <<'EOF'
#!/bin/bash
apt-get update -y
apt-get install -y nginx
echo 'Front A' > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx
EOF
)" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region $REGION)


  

FRONT2=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --network-interfaces "AssociatePublicIpAddress=true,DeviceIndex=0,SubnetId=$SUBNET_PUBLIC_B_ID,Groups=$SG_FRONT" \
  --user-data "$(cat <<'EOF'
#!/bin/bash
apt-get update -y
apt-get install -y nginx
echo 'Front B' > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx
EOF
)" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region $REGION)


  echo "Aguardando instâncias iniciarem..."

aws ec2 wait instance-status-ok \
  --instance-ids $FRONT1 $FRONT2 \
  --region $REGION
  
DB1=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-group-ids $SG_DB --subnet-id $SUBNET_DB_A_ID --query 'Instances[0].InstanceId' --output text --region $REGION)

BACK1=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-group-ids $SG_BACK --subnet-id $SUBNET_BACK_A_ID --query 'Instances[0].InstanceId' --output text --region $REGION)

BACK2=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-group-ids $SG_BACK --subnet-id $SUBNET_BACK_B_ID --query 'Instances[0].InstanceId' --output text --region $REGION)

# ALB Front
LB_SG=$(aws ec2 create-security-group --group-name lb-front --description "LB" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)

aws ec2 authorize-security-group-ingress --group-id $LB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT --protocol tcp --port 80 --source-group $LB_SG --region $REGION

LB=$(aws elbv2 describe-load-balancers \
  --names alb-front \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text \
  --region $REGION 2>/dev/null || echo "")

if [ -z "$LB" ] || [ "$LB" == "None" ]; then
  echo "Criando Load Balancer..."

  LB=$(aws elbv2 create-load-balancer \
    --name alb-front \
    --subnets $SUBNET_PUBLIC_A_ID $SUBNET_PUBLIC_B_ID \
    --security-groups $LB_SG \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text \
    --region $REGION)
else
  echo "Load Balancer já existe"
fi

echo "Verificando Target Group..."

TG=""
TG_VPC=""

# tenta pegar TG existente
TG=$(aws elbv2 describe-target-groups \
  --names tg-front \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text \
  --region $REGION 2>/dev/null || echo "")

if [ -n "$TG" ] && [ "$TG" != "None" ]; then
  TG_VPC=$(aws elbv2 describe-target-groups \
    --target-group-arns $TG \
    --query "TargetGroups[0].VpcId" \
    --output text \
    --region $REGION)
fi

# se não existe OU está em outra VPC → cria novo
if [ -z "$TG" ] || [ "$TG" == "None" ] || [ "$TG_VPC" != "$VPC_ID" ]; then
  echo "Criando novo Target Group (VPC incompatível ou inexistente)"

export MSYS_NO_PATHCONV=1
  TG=$(aws elbv2 create-target-group \
    --name tg-front-$(date +%s) \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type instance \
    --health-check-path "/" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text \
    --region $REGION)
else
  echo "Reutilizando Target Group existente"
fi

aws ec2 describe-instances \
  --instance-ids $FRONT1 \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text \
  --region $REGION

echo "Aguardando nginx responder..."

for i in {1..30}; do
  IP1=$(aws ec2 describe-instances --instance-ids $FRONT1 --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)
  IP2=$(aws ec2 describe-instances --instance-ids $FRONT2 --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)

  if curl -s http://$IP1 | grep -q "Front" && curl -s http://$IP2 | grep -q "Front"; then
    echo "Nginx pronto nas duas instâncias"
    break
  fi

  echo "tentativa $i..."
  sleep 10
done

aws elbv2 register-targets --target-group-arn $TG --targets Id=$FRONT1 Id=$FRONT2 --region $REGION

aws elbv2 create-listener \
  --load-balancer-arn $LB \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG \
  --region $REGION

# ALB Back (Interno)
LB_BACK_SG=$(aws ec2 create-security-group \
  --group-name lb-back \
  --description "LB Back" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text \
  --region $REGION)

aws ec2 authorize-security-group-ingress \
  --group-id $LB_BACK_SG \
  --protocol tcp \
  --port 8080 \
  --source-group $SG_FRONT \
  --region $REGION

aws ec2 authorize-security-group-ingress \
  --group-id $SG_BACK \
  --protocol tcp \
  --port 8080 \
  --source-group $LB_BACK_SG \
  --region $REGION

LB_BACK=$(aws elbv2 create-load-balancer \
  --name alb-back \
  --subnets $SUBNET_BACK_A_ID $SUBNET_BACK_B_ID \
  --security-groups $LB_BACK_SG \
  --scheme internal \
  --type application \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text \
  --region $REGION)

TG_BACK=$(aws elbv2 create-target-group \
  --name tg-back \
  --protocol HTTP \
  --port 8080 \
  --vpc-id $VPC_ID \
  --target-type instance \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text \
  --region $REGION)

aws elbv2 register-targets \
  --target-group-arn $TG_BACK \
  --targets Id=$BACK1 Id=$BACK2 \
  --region $REGION

aws elbv2 create-listener \
  --load-balancer-arn $LB_BACK \
  --protocol HTTP \
  --port 8080 \
  --default-actions Type=forward,TargetGroupArn=$TG_BACK \
  --region $REGION

echo "Infra criada com sucesso"