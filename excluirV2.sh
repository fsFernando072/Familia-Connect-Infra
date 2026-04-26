#!/bin/bash
REGION="us-east-1"
VPC_NAME="vpc-familia-connect"
KEY_NAME="myssh"

# Obter VPC
VPC_ID=$(aws ec2 describe-vpcs \
    --filters Name=tag:Name,Values=$VPC_NAME \
    --query 'Vpcs[0].VpcId' \
    --output text --region $REGION)

if [ "$VPC_ID" == "None" ]; then
    echo "Nenhuma VPC encontrada com o nome $VPC_NAME na região $REGION."
    exit 1
fi

echo "Excluindo Load Balancers..."
LB_ARNS=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
    --output text --region $REGION)
for lb in $LB_ARNS; do
    aws elbv2 delete-load-balancer --load-balancer-arn $lb --region $REGION || true
done

echo "Excluindo Target Groups..."
TG_ARNS=$(aws elbv2 describe-target-groups \
    --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" \
    --output text --region $REGION)
for tg in $TG_ARNS; do
    aws elbv2 delete-target-group --target-group-arn $tg --region $REGION || true
done

echo "Excluindo instâncias..."
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text --region $REGION)
if [ -n "$INSTANCE_IDS" ]; then
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
fi

echo "Excluindo NAT Gateway..."
NATGW_IDS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query "NatGateways[].NatGatewayId" \
    --output text --region $REGION)
for nat in $NATGW_IDS; do
    aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $REGION || true
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids $nat --region $REGION || true
done

echo "Liberando Elastic IPs..."
EIP_ALLOC_IDS=$(aws ec2 describe-addresses \
    --filters "Name=domain,Values=vpc" \
    --query "Addresses[].AllocationId" \
    --output text --region $REGION)
for eip in $EIP_ALLOC_IDS; do
    aws ec2 release-address --allocation-id $eip --region $REGION || true
done

echo "Excluindo Internet Gateway..."
IGW_IDS=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query "InternetGateways[].InternetGatewayId" \
    --output text --region $REGION)
for igw in $IGW_IDS; do
    aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $VPC_ID --region $REGION || true
    aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $REGION || true
done

echo "Excluindo Route Tables..."
RTB_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "RouteTables[].RouteTableId" \
    --output text --region $REGION)
for rtb in $RTB_IDS; do
    ASSOC_IDS=$(aws ec2 describe-route-tables --route-table-ids $rtb \
        --query "RouteTables[].Associations[?Main==\`false\`].RouteTableAssociationId" \
        --output text --region $REGION)
    for assoc in $ASSOC_IDS; do
        aws ec2 disassociate-route-table --association-id $assoc --region $REGION || true
    done
    aws ec2 delete-route-table --route-table-id $rtb --region $REGION || true
done

echo "Excluindo Subnets..."
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[].SubnetId" \
    --output text --region $REGION)
for subnet in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id $subnet --region $REGION || true
done

echo "Excluindo Security Groups..."
SG_IDS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[].GroupId" \
    --output text --region $REGION)
for sg in $SG_IDS; do
    aws ec2 delete-security-group --group-id $sg --region $REGION || true
done

echo "Excluindo Network ACLs..."
ACL_IDS=$(aws ec2 describe-network-acls \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "NetworkAcls[?IsDefault==\`false\`].NetworkAclId" \
    --output text --region $REGION)
for acl in $ACL_IDS; do
    aws ec2 delete-network-acl --network-acl-id $acl --region $REGION || true
done

echo "Excluindo VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION || true

echo "Infraestrutura da VPC $VPC_NAME excluída com sucesso!"
