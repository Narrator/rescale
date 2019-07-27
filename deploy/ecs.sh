#!/bin/bash

source .env

# Create ECS cluster
ecs-cli up --keypair ${KEYPAIR} --capability-iam --size 2 \
    --subnets ${PUB_SUBNET_1},${PUB_SUBNET_2},${PUB_SUBNET_3} \
    --vpc ${VPC_ID} --instance-type t3.micro --launch-type EC2 \
    --cluster rescale-portal-cluster --region us-east-2 --security-group ${SG_ID} --force

ecs-cli up --keypair ${KEYPAIR} --capability-iam --size 2 \
    --subnets ${PRIV_SUBNET_1},${PRIV_SUBNET_2},${PRIV_SUBNET_3} \
    --vpc ${VPC_ID} --instance-type t3.micro --no-associate-public-ip-address --launch-type EC2 \
    --cluster rescale-hardware-cluster --region us-east-2 --security-group ${SG_ID} --force

# # ECS register task definition
aws ecs register-task-definition --cli-input-json file://portal-task.json
aws ecs register-task-definition --cli-input-json file://hardware-task.json

# # ECS create services
aws ecs create-service --cli-input-json file://portal-service.json
aws ecs create-service --cli-input-json file://hardware-service.json