#!/bin/bash

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.31.0.0/16 | jq -r .Vpc.VpcId)

# Create 2 subnets
PRIV_SUBNET_1=$(aws ec2 create-subnet --availability-zone us-east-2a --vpc-id ${VPC_ID} --cidr-block 10.31.16.0/20 | jq -r .Subnet.SubnetId)
PRIV_SUBNET_2=$(aws ec2 create-subnet --availability-zone us-east-2b --vpc-id ${VPC_ID} --cidr-block 10.31.32.0/20 | jq -r .Subnet.SubnetId)
PRIV_SUBNET_3=$(aws ec2 create-subnet --availability-zone us-east-2c --vpc-id ${VPC_ID} --cidr-block 10.31.48.0/20 | jq -r .Subnet.SubnetId)

PUB_SUBNET_1=$(aws ec2 create-subnet --availability-zone us-east-2a --vpc-id ${VPC_ID} --cidr-block 10.31.64.0/20 | jq -r .Subnet.SubnetId)
PUB_SUBNET_2=$(aws ec2 create-subnet --availability-zone us-east-2b --vpc-id ${VPC_ID} --cidr-block 10.31.80.0/20 | jq -r .Subnet.SubnetId)
PUB_SUBNET_2=$(aws ec2 create-subnet --availability-zone us-east-2c --vpc-id ${VPC_ID} --cidr-block 10.31.96.0/20 | jq -r .Subnet.SubnetId)

# Create internet gateway
IG_ID=$(aws ec2 create-internet-gateway | jq -r .InternetGateway.InternetGatewayId)

# Attach gateway to VPC
aws ec2 attach-internet-gateway --vpc-id ${VPC_ID} --internet-gateway-id ${IG_ID}

# Create Route Table for IGW
IG_RT_ID=$(aws ec2 create-route-table --vpc-id ${VPC_ID} | jq -r .RouteTable.RouteTableId)

# Create Route for IGW
aws ec2 create-route --route-table-id ${IG_RT_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${IG_ID}

# Associate and configure public subnets
aws ec2 associate-route-table  --subnet-id ${PUB_SUBNET_1} --route-table-id ${IG_RT_ID}
aws ec2 modify-subnet-attribute --subnet-id ${PUB_SUBNET_1} --map-public-ip-on-launch
aws ec2 associate-route-table  --subnet-id ${PUB_SUBNET_2} --route-table-id ${IG_RT_ID}
aws ec2 modify-subnet-attribute --subnet-id ${PUB_SUBNET_2} --map-public-ip-on-launch
aws ec2 associate-route-table  --subnet-id ${PUB_SUBNET_3} --route-table-id ${IG_RT_ID}
aws ec2 modify-subnet-attribute --subnet-id ${PUB_SUBNET_3} --map-public-ip-on-launch

# Create private route tables for NAT
PRIV_RT_ID_1=$(aws ec2 create-route-table --vpc-id ${VPC_ID} | jq -r .RouteTable.RouteTableId)
PRIV_RT_ID_2=$(aws ec2 create-route-table --vpc-id ${VPC_ID} | jq -r .RouteTable.RouteTableId)
PRIV_RT_ID_3=$(aws ec2 create-route-table --vpc-id ${VPC_ID} | jq -r .RouteTable.RouteTableId)

# Associate private subnet
aws ec2 associate-route-table  --subnet-id ${PRIV_SUBNET_1} --route-table-id ${PRIV_RT_ID_1}
aws ec2 associate-route-table  --subnet-id ${PRIV_SUBNET_2} --route-table-id ${PRIV_RT_ID_2}
aws ec2 associate-route-table  --subnet-id ${PRIV_SUBNET_3} --route-table-id ${PRIV_RT_ID_3}

# Create NAT gateway for private subnet to access internet
ELASTIC_IP_1=$(aws ec2 allocate-address | jq -r .AllocationId)
ELASTIC_IP_2=$(aws ec2 allocate-address | jq -r .AllocationId)
ELASTIC_IP_3=$(aws ec2 allocate-address | jq -r .AllocationId)

sleep 30

NAT_ID_1=$(aws ec2 create-nat-gateway --allocation-id=${ELASTIC_IP_1} --subnet-id ${PUB_SUBNET_1} | jq -r .NatGateway.NatGatewayId)
NAT_ID_2=$(aws ec2 create-nat-gateway --allocation-id=${ELASTIC_IP_2} --subnet-id ${PUB_SUBNET_2} | jq -r .NatGateway.NatGatewayId)
NAT_ID_3=$(aws ec2 create-nat-gateway --allocation-id=${ELASTIC_IP_3} --subnet-id ${PUB_SUBNET_3} | jq -r .NatGateway.NatGatewayId)

sleep 30

aws ec2 create-route --route-table-id ${PRIV_RT_ID_1} --destination-cidr-block 0.0.0.0/0 --gateway-id ${NAT_ID_1}
aws ec2 create-route --route-table-id ${PRIV_RT_ID_2} --destination-cidr-block 0.0.0.0/0 --gateway-id ${NAT_ID_2}
aws ec2 create-route --route-table-id ${PRIV_RT_ID_3} --destination-cidr-block 0.0.0.0/0 --gateway-id ${NAT_ID_3}

# Create security groups
SG_ID=$(aws ec2 create-security-group --group-name ecs-sg --description ecs-sg --vpc-id ${VPC_ID} | jq -r .GroupId)
ALB_SG_ID=$(aws ec2 create-security-group --group-name alb-ecs-sg --description alb-ecs-sg --vpc-id ${VPC_ID} | jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol tcp --port 1-65535 --source-group ${ALB_SG_ID}


