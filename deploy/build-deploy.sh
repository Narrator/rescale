#!/bin/bash

source .env
echo "${DOCKER_HUB_PASS}" | docker login --username=${DOCKER_HUB_USER} --password-stdin
docker build -t kausubmab/rescale-hp ../
docker push kausubmab/rescale-hp

# Update task definitions - Maybe new enivornment variables were added?
aws ecs register-task-definition --cli-input-json file://hardware-task.json
aws ecs register-task-definition --cli-input-json file://portal-task.json

# Deploy new image
aws ecs update-service --cluster rescale-hardware-cluster --service rescale-hardware --force-new-deployment
aws ecs update-service --cluster rescale-portal-cluster --service rescale-portal --force-new-deployment