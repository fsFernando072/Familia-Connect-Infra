#!/bin/bash

# Variáveis
VPC_NAME="vpc-familia-connect"
CIDR_BLOCK="10.0.0.0/20"
SUBNET_PUBLIC_A_CIDR="10.0.1.0/24"
SUBNET_PUBLIC_B_CIDR="10.0.2.0/24"
SUBNET_BACK_A_CIDR="10.0.3.0/24"
SUBNET_BACK_B_CIDR="10.0.4.0/24"
SUBNET_DB_A_CIDR="10.0.5.0/24"
REGION="us-east-1"
AMI_ID="ami-0c7217cdde317cfec"   # Ubuntu Server 22.04 LTS (x86)
INSTANCE_TYPE="t3.micro"
KEY_NAME="myssh"
S3_BRONZE_BUCKET="familia-connect-bronze-bucket"
S3_SILVER_BUCKET="familia-connect-silver-bucket"
S3_GOLD_BUCKET="familia-connect-gold-bucket"

# Criar par de chaves
echo "Criando par de chaves $KEY_NAME..."
aws ec2 create-key-pair \
    --key-name $KEY_NAME \
    --region us-east-1 \
    --query 'KeyMaterial' \
    --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem
echo "Par de chaves criada e salva em $KEY_NAME.pem"

# Criar VPC
echo -e "\nCriando VPC $VPC_NAME..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $CIDR_BLOCK \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
    --query 'Vpc.VpcId' \
    --output text \
    --region $REGION)

aws ec2 describe-vpcs \
    --vpc-ids $VPC_ID \
    --query "Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,State:State}" \
    --output table --region $REGION

# Criar sub-redes
echo -e "\nCriando sub-redes..."
SUBNET_PUBLIC_A_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_PUBLIC_A_CIDR \
    --availability-zone ${REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=sub-rede-publica-A}]" \
    --query 'Subnet.SubnetId' \
    --output text \
    --region $REGION)

aws ec2 describe-subnets \
    --subnet-ids $SUBNET_PUBLIC_A_ID \
    --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
    --output table \
    --region $REGION

SUBNET_PUBLIC_B_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_PUBLIC_B_CIDR \
    --availability-zone ${REGION}b \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=sub-rede-publica-B}]" \
    --query 'Subnet.SubnetId' \
    --output text \
    --region $REGION)

aws ec2 describe-subnets \
    --subnet-ids $SUBNET_PUBLIC_B_ID \
    --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
    --output table \
    --region $REGION

SUBNET_BACK_A_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_BACK_A_CIDR \
    --availability-zone ${REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=sub-rede-back-A}]" \
    --query 'Subnet.SubnetId' \
    --output text \
    --region $REGION)

aws ec2 describe-subnets \
    --subnet-ids $SUBNET_BACK_A_ID \
    --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
    --output table \
    --region $REGION

SUBNET_BACK_B_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_BACK_B_CIDR \
    --availability-zone ${REGION}b \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=sub-rede-back-B}]" \
    --query 'Subnet.SubnetId' \
    --output text \
    --region $REGION)

aws ec2 describe-subnets \
    --subnet-ids $SUBNET_BACK_B_ID \
    --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
    --output table \
    --region $REGION

SUBNET_DB_A_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_DB_A_CIDR \
    --availability-zone ${REGION}a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=sub-rede-db-A}]" \
    --query 'Subnet.SubnetId' \
    --output text \
    --region $REGION)

aws ec2 describe-subnets \
    --subnet-ids $SUBNET_DB_A_ID \
    --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
    --output table \
    --region $REGION

# Internet Gateway + Route Tables
echo -e "\nCriando Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_NAME}-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text \
    --region $REGION)

aws ec2 describe-internet-gateways \
    --internet-gateway-ids $IGW_ID \
    --query "InternetGateways[].{IGW:InternetGatewayId}" \
    --output table \
    --region $REGION

aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID \
    --region $REGION

echo -e "\nCriando Route Table pública..."
RTB_PUBLIC_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-public}]" \
    --query 'RouteTable.RouteTableId' \
    --output text --region $REGION)

aws ec2 describe-route-tables \
    --route-table-ids $RTB_PUBLIC_ID \
    --query "RouteTables[].{RouteTableId:RouteTableId,VpcId:VpcId}" \
    --output table \
    --region $REGION

aws ec2 create-route \
    --route-table-id $RTB_PUBLIC_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID \
    --query '{RouteCreated:Return}' \
    --output table \
    --region $REGION

aws ec2 associate-route-table \
    --route-table-id $RTB_PUBLIC_ID \
    --subnet-id $SUBNET_PUBLIC_A_ID \
    --query '{AssociationId:AssociationId}' \
    --output table \
    --region $REGION

aws ec2 associate-route-table \
    --route-table-id $RTB_PUBLIC_ID \
    --subnet-id $SUBNET_PUBLIC_B_ID \
    --query '{AssociationId:AssociationId}' \
    --output table \
    --region $REGION

# NAT Gateway + Route Table privada
echo -e "\nCriando NAT Gateway..."
EIP_ALLOC_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --query 'AllocationId' \
    --output text \
    --region $REGION)

NATGW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $SUBNET_PUBLIC_A_ID \
    --allocation-id $EIP_ALLOC_ID \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${VPC_NAME}-natgw}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text \
    --region $REGION)

aws ec2 wait nat-gateway-available \
    --nat-gateway-ids $NATGW_ID \
    --region $REGION

aws ec2 describe-nat-gateways \
    --nat-gateway-ids $NATGW_ID \
    --query "NatGateways[].{NatGatewayId:NatGatewayId,State:State}" \
    --output table --region $REGION

echo -e "\nCriando Route Table privada..."
RTB_PRIVATE_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-rtb-private}]" \
    --query 'RouteTable.RouteTableId' \
    --output text \
    --region $REGION)

aws ec2 describe-route-tables \
    --route-table-ids $RTB_PRIVATE_ID \
    --query "RouteTables[].{RouteTableId:RouteTableId,VpcId:VpcId}" \
    --output table \
    --region $REGION

aws ec2 create-route \
    --route-table-id $RTB_PRIVATE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NATGW_ID \
    --query '{RouteCreated:Return}' \
    --output table \
    --region $REGION

aws ec2 associate-route-table \
    --route-table-id $RTB_PRIVATE_ID \
    --subnet-id $SUBNET_BACK_A_ID \
    --query '{AssociationId:AssociationId}' \
    --output table \
    --region $REGION

aws ec2 associate-route-table \
    --route-table-id $RTB_PRIVATE_ID \
    --subnet-id $SUBNET_BACK_B_ID \
    --query '{AssociationId:AssociationId}' \
    --output table \
    --region $REGION

aws ec2 associate-route-table \
    --route-table-id $RTB_PRIVATE_ID \
    --subnet-id $SUBNET_DB_A_ID \
    --query '{AssociationId:AssociationId}' \
    --output table \
    --region $REGION

# Criação ACLs
echo -e "\nCriando ACL Pública"
ACL_PUBLIC_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-publica}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text \
    --region $REGION)

ASSOC_PUBLIC_A_ID=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_PUBLIC_A_ID" \
    --query "NetworkAcls[].Associations[?SubnetId=='$SUBNET_PUBLIC_A_ID'].NetworkAclAssociationId" \
    --output text \
    --region $REGION)

aws ec2 replace-network-acl-association \
    --association-id $ASSOC_PUBLIC_A_ID \
    --network-acl-id $ACL_PUBLIC_ID \
    --region $REGION \
    >/dev/null

ASSOC_PUBLIC_B_ID=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_PUBLIC_B_ID" \
    --query "NetworkAcls[].Associations[?SubnetId=='$SUBNET_PUBLIC_B_ID'].NetworkAclAssociationId" \
    --output text \
    --region $REGION)

aws ec2 replace-network-acl-association \
    --association-id $ASSOC_PUBLIC_B_ID \
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
    --rule-number 400 --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --ingress \
    --rule-number 500 --protocol tcp --port-range From=32000,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

# Regras de saída ACL pública
aws ec2 create-network-acl-entry --network-acl-id $ACL_PUBLIC_ID --egress \
    --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

echo -e "\nCriando ACL do back"
ACL_BACK_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-back}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text \
    --region $REGION)

ASSOC_BACK_A_ID=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_BACK_A_ID" \
    --query "NetworkAcls[].Associations[?SubnetId=='$SUBNET_BACK_A_ID'].NetworkAclAssociationId" \
    --output text \
    --region $REGION)

aws ec2 replace-network-acl-association \
    --association-id $ASSOC_BACK_A_ID \
    --network-acl-id $ACL_BACK_ID \
    --region $REGION \
    >/dev/null

ASSOC_BACK_B_ID=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_BACK_B_ID" \
    --query "NetworkAcls[].Associations[?SubnetId=='$SUBNET_BACK_B_ID'].NetworkAclAssociationId" \
    --output text \
    --region $REGION)

aws ec2 replace-network-acl-association \
    --association-id $ASSOC_BACK_B_ID \
    --network-acl-id $ACL_BACK_ID \
    --region $REGION \
    >/dev/null

# Mostrar ACL back criada
aws ec2 describe-network-acls \
    --network-acl-ids $ACL_BACK_ID \
    --query "NetworkAcls[].{ACL_ID:NetworkAclId,VPC:VpcId,Associations:Associations[].SubnetId}" \
    --output table \
    --region $REGION

# Regras de entrada ACL do back
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 100 --protocol tcp --port-range From=22,To=22 --cidr-block $SUBNET_PUBLIC_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 200 --protocol tcp --port-range From=22,To=22 --cidr-block $SUBNET_PUBLIC_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 300 --protocol tcp --port-range From=80,To=80 --cidr-block $SUBNET_PUBLIC_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 400 --protocol tcp --port-range From=80,To=80 --cidr-block $SUBNET_PUBLIC_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 500 --protocol tcp --port-range From=443,To=443 --cidr-block $SUBNET_PUBLIC_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 600 --protocol tcp --port-range From=443,To=443 --cidr-block $SUBNET_PUBLIC_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 700 --protocol tcp --port-range From=8080,To=8080 --cidr-block $SUBNET_PUBLIC_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 800 --protocol tcp --port-range From=8080,To=8080 --cidr-block $SUBNET_PUBLIC_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --ingress \
    --rule-number 900 --protocol tcp --port-range From=32000,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

# Regras de saída ACL do back
aws ec2 create-network-acl-entry --network-acl-id $ACL_BACK_ID --egress \
    --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

echo -e "\nCriando ACL DB"
ACL_DB_ID=$(aws ec2 create-network-acl \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=acl-db}]" \
    --query 'NetworkAcl.NetworkAclId' \
    --output text \
    --region $REGION)

ASSOC_DB_ID=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$SUBNET_DB_A_ID" \
    --query "NetworkAcls[].Associations[?SubnetId=='$SUBNET_DB_A_ID'].NetworkAclAssociationId" \
    --output text --region $REGION)

aws ec2 replace-network-acl-association \
    --association-id $ASSOC_DB_ID \
    --network-acl-id $ACL_DB_ID \
    --region $REGION \
    >/dev/null

# Mostrar ACL DB criada
aws ec2 describe-network-acls \
    --network-acl-ids $ACL_DB_ID \
    --query "NetworkAcls[].{ACL_ID:NetworkAclId,VPC:VpcId,Associations:Associations[].SubnetId}" \
    --output table \
    --region $REGION

# Regras de entrada ACL DB
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 100 --protocol tcp --port-range From=22,To=22 --cidr-block $SUBNET_BACK_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 200 --protocol tcp --port-range From=22,To=22 --cidr-block $SUBNET_BACK_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 300 --protocol tcp --port-range From=80,To=80 --cidr-block $SUBNET_BACK_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 400 --protocol tcp --port-range From=80,To=80 --cidr-block $SUBNET_BACK_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 500 --protocol tcp --port-range From=3306,To=3306 --cidr-block $SUBNET_BACK_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 600 --protocol tcp --port-range From=3306,To=3306 --cidr-block $SUBNET_BACK_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 700 --protocol tcp --port-range From=443,To=443 --cidr-block $SUBNET_BACK_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 800 --protocol tcp --port-range From=443,To=443 --cidr-block $SUBNET_BACK_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 900 --protocol tcp --port-range From=8080,To=8080 --cidr-block $SUBNET_BACK_A_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 1000 --protocol tcp --port-range From=8080,To=8080 --cidr-block $SUBNET_BACK_B_CIDR --rule-action allow --region $REGION
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --ingress \
    --rule-number 1100 --protocol tcp --port-range From=32000,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

# Regras de saída ACL DB
aws ec2 create-network-acl-entry --network-acl-id $ACL_DB_ID --egress \
    --rule-number 100 --protocol -1 --cidr-block 0.0.0.0/0 --rule-action allow --region $REGION

# Security Groups
echo -e "\nCriando Security Groups..."
SG_FRONT_ID=$(aws ec2 create-security-group \
    --group-name front-sg \
    --description "Front-end SG" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text \
    --region $REGION)

aws ec2 describe-security-groups \
    --group-ids $SG_FRONT_ID \
    --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName}" \
    --output table \
    --region $REGION

aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_FRONT_ID --protocol tcp --port 3333 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION

SG_BACK_ID=$(aws ec2 create-security-group --group-name back-sg --description "Back-end SG" --vpc-id $VPC_ID \
    --query 'GroupId' --output text --region $REGION)

aws ec2 describe-security-groups \
    --group-ids $SG_BACK_ID \
    --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName}" \
    --output table \
    --region $REGION

aws ec2 authorize-security-group-ingress --group-id $SG_BACK_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_BACK_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --query '{RuleCreated:Return,Port:SecurityGroupRules[0].FromPort}' --output table --region $REGION
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
INSTANCE_FRONT_A_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_FRONT_ID \
    --subnet-id $SUBNET_PUBLIC_A_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ec2-front-A}]" \
    --user-data file://config_front.sh \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)
echo "Instância FRONT A criada: $INSTANCE_FRONT_A_ID"

INSTANCE_FRONT_B_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_FRONT_ID \
    --subnet-id $SUBNET_PUBLIC_B_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ec2-front-B}]" \
    --user-data file://config_front.sh \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)
echo "Instância FRONT B criada: $INSTANCE_FRONT_B_ID"

INSTANCE_BACK_A_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_BACK_ID \
    --subnet-id $SUBNET_BACK_A_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ec2-back-A}]" \
    --user-data file://config_back.sh \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)
echo "Instância BACK A criada: $INSTANCE_BACK_A_ID"

INSTANCE_BACK_B_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_BACK_ID \
    --subnet-id $SUBNET_BACK_B_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ec2-back-B}]" \
    --user-data file://config_back.sh \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)
echo "Instância BACK B criada: $INSTANCE_BACK_B_ID"

INSTANCE_DB_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_DB_ID \
    --subnet-id $SUBNET_DB_A_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ec2-db}]" \
    --user-data file://config_db.sh \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)
echo "Instância DB criada: $INSTANCE_DB_ID"

echo -e "\nAssociando IP elástico nas VMs públicas"
ALLOCATION_A_ID=$(aws ec2 allocate-address \
    --query 'AllocationId' \
    --output text \
    --region $REGION)

ALLOCATION_B_ID=$(aws ec2 allocate-address \
    --query 'AllocationId' \
    --output text \
    --region $REGION)

aws ec2 associate-address \
    --instance-id "$INSTANCE_FRONT_A_ID" \
    --allocation-id "$ALLOCATION_A_ID" \
    --output text \
    >/dev/null

aws ec2 associate-address \
    --instance-id "$INSTANCE_FRONT_B_ID" \
    --allocation-id "$ALLOCATION_B_ID" \
    --output text \
    >/dev/null

# Criar Load Balancer para o FRONT
echo -e "\nCriando Load Balancer FRONT..."
LB_FRONT_ARN=$(aws elbv2 create-load-balancer \
    --name lb-front \
    --subnets $SUBNET_PUBLIC_A_ID $SUBNET_PUBLIC_B_ID \
    --security-groups $SG_FRONT_ID \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text \
    --region $REGION)

echo "Load Balancer FRONT criado: $LB_FRONT_ARN"

# Criar Target Group para o FRONT
export MSYS_NO_PATHCONV=1
TG_FRONT_ARN=$(aws elbv2 create-target-group \
    --name tg-front \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type instance \
    --health-check-path "/" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text \
    --region $REGION)

# Registrar instâncias FRONT no Target Group
aws elbv2 register-targets \
    --target-group-arn $TG_FRONT_ARN \
    --targets Id=$INSTANCE_FRONT_A_ID Id=$INSTANCE_FRONT_B_ID \
    --region $REGION

# Criar Listener para o FRONT
LISTENER_FRONT_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $LB_FRONT_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_FRONT_ARN \
    --query 'Listeners[0].ListenerArn' \
    --output text \
    --region $REGION)

aws elbv2 describe-listeners \
    --listener-arns $LISTENER_FRONT_ARN \
    --query "Listeners[].{ARN:ListenerArn,Port:Port,Protocol:Protocol}" \
    --output table \
    --region $REGION

# Criar Load Balancer para o BACK
echo -e "\nCriando Load Balancer BACK..."
LB_BACK_ARN=$(aws elbv2 create-load-balancer \
    --name lb-back \
    --subnets $SUBNET_BACK_A_ID $SUBNET_BACK_B_ID \
    --security-groups $SG_BACK_ID \
    --scheme internal \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text \
    --region $REGION)

echo "Load Balancer BACK criado: $LB_BACK_ARN"

# Criar Target Group para o BACK
TG_BACK_ARN=$(aws elbv2 create-target-group \
    --name tg-back \
    --protocol HTTP \
    --port 8080 \
    --vpc-id $VPC_ID \
    --target-type instance \
    --health-check-path "/" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text \
    --region $REGION)

# Registrar instâncias BACK no Target Group
aws elbv2 register-targets \
    --target-group-arn $TG_BACK_ARN \
    --targets Id=$INSTANCE_BACK_A_ID Id=$INSTANCE_BACK_B_ID \
    --region $REGION

# Criar Listener para o BACK
LISTENER_BACK_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $LB_BACK_ARN \
    --protocol HTTP \
    --port 8080 \
    --default-actions Type=forward,TargetGroupArn=$TG_BACK_ARN \
    --query 'Listeners[0].ListenerArn' \
    --output text \
    --region $REGION)

aws elbv2 describe-listeners \
    --listener-arns $LISTENER_BACK_ARN \
    --query "Listeners[].{ARN:ListenerArn,Port:Port,Protocol:Protocol}" \
    --output table \
    --region $REGION

echo -e "\nEsperando LOAD Balancers ficarem disponíveis..."
aws elbv2 wait load-balancer-available \
    --load-balancer-arns $LB_FRONT_ARN \
    --region $REGION

# Exibir tabela com IPs e nomes
echo ""
echo "======================================"
echo " Instâncias criadas na VPC $VPC_NAME "
echo "======================================"
aws ec2 describe-instances \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}" \
    --output table --region $REGION

#Criar buckets S3
echo -e "\nCriando buckets S3..."

aws s3api create-bucket \
    --bucket $S3_BRONZE_BUCKET \
    --region $REGION

echo "Bucket bronze criado: $S3_BRONZE_BUCKET"

aws s3api create-bucket \
    --bucket $S3_SILVER_BUCKET \
    --region $REGION

echo "Bucket silver criado: $S3_SILVER_BUCKET"

aws s3api create-bucket \
    --bucket $S3_GOLD_BUCKET \
    --region $REGION

echo "Bucket gold criado: $S3_GOLD_BUCKET"

# Listar buckets criados
aws s3api list-buckets \
    --query "Buckets[].Name" \
    --output table

