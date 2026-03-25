#!/bin/bash

# Variáveis
VPC_NAME="minha-vpc-01"
CIDR_BLOCK="10.0.0.0/24"
SUBNET_PUBLIC_CIDR="10.0.0.0/25"
SUBNET_PRIVATE_CIDR="10.0.0.128/25"
REGION="us-east-1"
AMI_ID="ami-0c7217cdde317cfec"   # Ubuntu Server 22.04 LTS (x86)
INSTANCE_TYPE="t2.micro"
KEY_NAME="myssh"

# Criar par de chaves
echo "Criando par de chaves $KEY_NAME..."
aws ec2 create-key-pair \
    --key-name minhachave \
    --region us-east-1 \
    --query 'KeyMaterial' \
    --output text > minhachave.pem
chmod 400 $KEY_NAME.pem
echo "Par de chaves criada e salva em $KEY_NAME.pem"

# Criar VPC
echo -e "\nCriando VPC $VPC_NAME..."
VPC_ID=$(aws ec2 create-vpc --cidr-block $CIDR_BLOCK \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
    --query 'Vpc.VpcId' --output text --region $REGION)

aws ec2 describe-vpcs \
    --vpc-ids $VPC_ID \
    --query "Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,State:State}" \
    --output table --region $REGION

# Criar sub-redes
echo -e "\nCriando sub-redes..."
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PUBLIC_CIDR \
    --availability-zone ${REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=sub-rede-publica}]" \
    --query 'Subnet.SubnetId' --output text --region $REGION)

aws ec2 describe-subnets \
    --subnet-ids $SUBNET_PUBLIC_ID \
    --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
    --output table --region $REGION

SUBNET_PRIVATE_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_PRIVATE_CIDR \
    --availability-zone ${REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=sub-rede-privada}]" \
    --query 'Subnet.SubnetId' --output text --region $REGION)

aws ec2 describe-subnets \
    --subnet-ids $SUBNET_PRIVATE_ID \
    --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
    --output table --region $REGION

# Internet Gateway + Route Tables
echo -e "\nCriando Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_NAME}-igw}]" \
    --query 'InternetGateway.InternetGatewayId' --output text --region $REGION)

aws ec2 describe-internet-gateways \
    --internet-gateway-ids $IGW_ID \
    --query "InternetGateways[].{IGW:InternetGatewayId}" \
    --output table --region $REGION

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION

echo -e "\nCriando Route Table pública..."
RTB_PUBLIC_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-public}]" \
    --query 'RouteTable.RouteTableId' --output text --region $REGION)

aws ec2 describe-route-tables \
    --route-table-ids $RTB_PUBLIC_ID \
    --query "RouteTables[].{RouteTableId:RouteTableId,VpcId:VpcId}" \
    --output table --region $REGION

aws ec2 create-route \
    --route-table-id $RTB_PUBLIC_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID \
    --query '{RouteCreated:Return}' \
    --output table \
    --region $REGION

aws ec2 associate-route-table \
    --route-table-id $RTB_PUBLIC_ID \
    --subnet-id $SUBNET_PUBLIC_ID \
    --query '{AssociationId:AssociationId}' \
    --output table \
    --region $REGION

# NAT Gateway + Route Table privada
echo -e "\nCriando NAT Gateway..."
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text --region $REGION)

NATGW_ID=$(aws ec2 create-nat-gateway --subnet-id $SUBNET_PUBLIC_ID --allocation-id $EIP_ALLOC_ID \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${VPC_NAME}-natgw}]" \
    --query 'NatGateway.NatGatewayId' --output text --region $REGION)

aws ec2 wait nat-gateway-available --nat-gateway-ids $NATGW_ID --region $REGION

aws ec2 describe-nat-gateways \
    --nat-gateway-ids $NATGW_ID \
    --query "NatGateways[].{NatGatewayId:NatGatewayId,State:State}" \
    --output table --region $REGION

echo -e "\nCriando Route Table privada..."
RTB_PRIVATE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-private}]" \
    --query 'RouteTable.RouteTableId' --output text --region $REGION)

aws ec2 describe-route-tables \
    --route-table-ids $RTB_PRIVATE_ID \
    --query "RouteTables[].{RouteTableId:RouteTableId,VpcId:VpcId}" \
    --output table --region $REGION

aws ec2 create-route \
    --route-table-id $RTB_PRIVATE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NATGW_ID \
    --query '{RouteCreated:Return}' \
    --output table \
    --region $REGION

aws ec2 associate-route-table \
    --route-table-id $RTB_PRIVATE_ID \
    --subnet-id $SUBNET_PRIVATE_ID \
    --query '{AssociationId:AssociationId}' \
    --output table \
    --region $REGION

# Criação ACLs
echo -e "\nCriando ACL Pública"
ACL_PUBLIC_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-publica}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text --region $REGION)

ASSOC_ID=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_PUBLIC_ID" \
    --query "NetworkAcls[0].Associations[0].NetworkAclAssociationId" \
    --output text --region $REGION)

aws ec2 replace-network-acl-association \
    --association-id $ASSOC_ID \
    --network-acl-id $ACL_PUBLIC_ID \
    --region $REGION \
    >/dev/null

# Mostrar ACL pública criada
aws ec2 describe-network-acls \
    --network-acl-ids $ACL_PUBLIC_ID \
    --query "NetworkAcls[].{ACL_ID:NetworkAclId,VPC:VpcId,Associations:Associations[].SubnetId}" \
    --output table --region $REGION

# Regras de entrada ACL pública
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress \
    --rule-number 100 --protocol tcp --port-range From=22,To=22 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress \
    --rule-number 200 --protocol tcp --port-range From=80,To=80 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress \
    --rule-number 300 --protocol tcp --port-range From=8080,To=8080 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress \
    --rule-number 400 --protocol tcp --port-range From=3333,To=3333 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress \
    --rule-number 500 --protocol tcp --port-range From=32000,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

# Regras de saída ACL pública
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --egress \
    --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

echo -e "\nCriando ACL Privada"
ACL_PRIVATE_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-privada}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text --region $REGION)

ASSOC_ID_PRIVATE=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_PRIVATE_ID" \
    --query "NetworkAcls[0].Associations[0].NetworkAclAssociationId" \
    --output text --region $REGION)

aws ec2 replace-network-acl-association \
    --association-id $ASSOC_ID_PRIVATE \
    --network-acl-id $ACL_PRIVATE_ID \
    --region $REGION \
    >/dev/null

# Mostrar ACL privada criada
aws ec2 describe-network-acls \
    --network-acl-ids $ACL_PRIVATE_ID \
    --query "NetworkAcls[].{ACL_ID:NetworkAclId,VPC:VpcId,Associations:Associations[].SubnetId}" \
    --output table --region $REGION

# Regras de entrada ACL privada
aws ec2 create-network-acl-entry --network-acl-id $ACL_PRIVATE_ID --ingress \
    --rule-number 100 --protocol tcp --port-range From=22,To=22 --cidr-block $SUBNET_PUBLIC_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PRIVATE_ID --ingress \
    --rule-number 200 --protocol tcp --port-range From=3306,To=3306 --cidr-block $SUBNET_PUBLIC_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PRIVATE_ID --ingress \
    --rule-number 300 --protocol tcp --port-range From=8080,To=8080 --cidr-block $SUBNET_PUBLIC_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PRIVATE_ID --ingress \
    --rule-number 400 --protocol tcp --port-range From=32000,To=65535 --cidr-block $SUBNET_PUBLIC_CIDR --rule-action allow --region $REGION

# Regras de saída ACL privada
aws ec2 create-network-acl-entry --network-acl-id $ACL_PRIVATE_ID --egress \
    --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

# Security Groups
echo -e "\nCriando Security Groups..."
SG_FRONT_ID=$(aws ec2 create-security-group --group-name front-sg --description "Front-end SG" --vpc-id $VPC_ID \
    --query 'GroupId' --output text --region $REGION)

aws ec2 describe-security-groups \
    --group-ids $SG_FRONT_ID \
    --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName}" \
    --output table --region $REGION

aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 3333 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION

SG_BACK_ID=$(aws ec2 create-security-group --group-name back-sg --description "Back-end SG" --vpc-id $VPC_ID \
    --query 'GroupId' --output text --region $REGION)

aws ec2 describe-security-groups \
    --group-ids $SG_BACK_ID \
    --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName}" \
    --output table --region $REGION

aws ec2 authorize-security-group-ingress --group-id $SG_BACK_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_BACK_ID --protocol tcp --port 8080 --source-group $SG_FRONT_ID --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION

SG_DB_ID=$(aws ec2 create-security-group --group-name db-sg --description "Database SG" --vpc-id $VPC_ID \
    --query 'GroupId' --output text --region $REGION)

aws ec2 describe-security-groups \
    --group-ids $SG_DB_ID \
    --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName}" \
    --output table --region $REGION

aws ec2 authorize-security-group-ingress --group-id $SG_DB_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_DB_ID --protocol tcp --port 3306 --source-group $SG_BACK_ID --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION

# Criar instâncias
echo -e "\nCriando instâncias EC2..."
INSTANCE_FRONT_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME --security-group-ids $SG_FRONT_ID --subnet-id $SUBNET_PUBLIC_ID --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ec2-front}]" \
    --query 'Instances[0].InstanceId' --output text --region $REGION)
echo "Instância FRONT criada: $INSTANCE_FRONT_ID"

INSTANCE_BACK_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME --security-group-ids $SG_BACK_ID --subnet-id $SUBNET_PRIVATE_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ec2-back}]" \
    --query 'Instances[0].InstanceId' --output text --region $REGION)
echo "Instância BACK criada: $INSTANCE_BACK_ID"

INSTANCE_DB_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME --security-group-ids $SG_DB_ID --subnet-id $SUBNET_PRIVATE_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ec2-db}]" \
    --query 'Instances[0].InstanceId' --output text --region $REGION)
echo "Instância DB criada: $INSTANCE_DB_ID"

# Exibir tabela com IPs e nomes
echo ""
echo "======================================"
echo " Instâncias criadas na VPC $VPC_NAME "
echo "======================================"
aws ec2 describe-instances \
    --instance-ids $INSTANCE_FRONT_ID $INSTANCE_BACK_ID $INSTANCE_DB_ID \
    --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}" \
    --output table --region $REGION