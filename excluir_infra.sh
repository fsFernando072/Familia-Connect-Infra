#!/bin/bash
REGION="us-east-1"
VPC_NAME="minha-vpc-01"
KEY_NAME="myssh"

# Obter VPC
VPC_ID=$(aws ec2 describe-vpcs \
    --filters Name=tag:Name,Values=$VPC_NAME \
    --query 'Vpcs[0].VpcId' \
    --output text --region $REGION)

aws ec2 describe-vpcs \
    --vpc-ids $VPC_ID \
    --query "Vpcs[].{VpcId:VpcId,CIDR:CidrBlock}" \
    --output table --region $REGION

echo "Excluindo instâncias"
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text --region $REGION)

aws ec2 describe-instances \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name}" \
    --output table --region $REGION

if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminando instâncias..."
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION \
        --query "TerminatingInstances[].{InstanceId:InstanceId,State:CurrentState.Name}" \
        --output table

    echo "Aguardando término das instâncias..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
    echo "Instâncias terminadas com sucesso."
else
    echo "Nenhuma instância encontrada na VPC."
fi

echo -e "\nExcluindo par de chaves"
aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION 2>/dev/null || true
rm -f $KEY_NAME.pem

echo -e "\nExcluindo NAT Gateway"
NATGW_ID=$(aws ec2 describe-nat-gateways \
    --filter "Name=tag:Name,Values=${VPC_NAME}-natgw" \
    --query "NatGateways[?State=='available'].NatGatewayId | [0]" \
    --output text --region $REGION)

if [ "$NATGW_ID" != "None" ]; then
  aws ec2 describe-nat-gateways \
      --nat-gateway-ids $NATGW_ID \
      --query "NatGateways[].{NatGatewayId:NatGatewayId,State:State}" \
      --output table --region $REGION
  aws ec2 delete-nat-gateway --nat-gateway-id $NATGW_ID --region $REGION
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NATGW_ID --region $REGION
fi

echo -e "\nLiberando Elastic IPs"
EIP_ALLOC_IDS=$(aws ec2 describe-addresses \
    --filters "Name=domain,Values=vpc" \
    --query "Addresses[].AllocationId" \
    --output text --region $REGION)

aws ec2 describe-addresses \
    --filters "Name=domain,Values=vpc" \
    --query "Addresses[].{AllocationId:AllocationId,PublicIP:PublicIp}" \
    --output table --region $REGION

for eip in $EIP_ALLOC_IDS; do
  echo "Liberando $eip..."
  aws ec2 release-address --allocation-id $eip --region $REGION || echo "Não foi possível liberar $eip (já liberado ou sem permissão)."
done

echo -e "\nExcluindo Internet Gateway"
IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=${VPC_NAME}-igw" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text --region $REGION)

if [ "$IGW_ID" != "None" ]; then
  aws ec2 describe-internet-gateways \
      --internet-gateway-ids $IGW_ID \
      --query "InternetGateways[].{IGW:InternetGatewayId}" \
      --output table --region $REGION
  aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION || true
  aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION || true
fi

echo -e "\nExcluindo Subnets"
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[].SubnetId" \
    --output text --region $REGION)

aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock}" \
    --output table --region $REGION

for subnet in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id $subnet --region $REGION || true
done

echo -e "\nExcluindo Route Tables"
RTB_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=${VPC_NAME}-rtb-public,${VPC_NAME}-rtb-private" \
    --query "RouteTables[].RouteTableId" \
    --output text --region $REGION)

aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=${VPC_NAME}-rtb-public,${VPC_NAME}-rtb-private" \
    --query "RouteTables[].{Name:Tags[?Key=='Name']|[0].Value,RouteTableId:RouteTableId}" \
    --output table --region $REGION

for rtb in $RTB_IDS; do
  ASSOC_IDS=$(aws ec2 describe-route-tables --route-table-ids $rtb \
      --query "RouteTables[].Associations[?Main==\`false\`].RouteTableAssociationId" \
      --output text --region $REGION)
  for assoc in $ASSOC_IDS; do
    aws ec2 disassociate-route-table --association-id $assoc --region $REGION || true
  done
  aws ec2 delete-route-table --route-table-id $rtb --region $REGION || true
done

echo -e "\nExcluindo Security Groups"
SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" \
    --output text --region $REGION)

aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[?GroupName!='default'].{GroupId:GroupId,Name:GroupName}" \
    --output table --region $REGION

for sg in $SG_IDS; do
  aws ec2 delete-security-group --group-id $sg --region $REGION || true
done

echo -e "\nExcluindo VPC"
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION || true

echo -e "\nInfraestrutura da VPC $VPC_NAME excluída com sucesso!"