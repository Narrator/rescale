# Rescale

Micro "microservices" Deployment

1. [Run Locally](#run-locally)
2. [Deploy first time](#deploy)
3. [Future deployments](#future-deployments)
4. [Service and Task definition files](service-and-task-definition-files)
5. [Infrastructure Overview](#infrastructure-overview)

## Run Locally

First clone this repo

```sh
git clone git@github.com:Narrator/rescale.git
cd rescale
```

Then follow these steps:

- [Prerequisites](#prerequisites)
- [Add environment variables](#environment-variables)

### Prerequisites

[Docker](https://www.docker.com/get-started) is the only requirement

### Environment variables

Add an `.env` file to the root of your project directory before trying to build.

```
SOCKET_URI=http://localhost:80
HARDWARE_HOST=rescale-hardware:5001

DB_HOST=mysql
DB_NAME=hardware
DB_USER=root
DB_PASS=password
```

### Build

Run these commands to get your local containers up and running.

```sh
docker-compose build
docker-compose up
```

## Deploy

Install the AWS CLI and configure your credentials. To create the VPC, Subnets, IGW, NAT Gateway and security groups, simply run these commands:

```
cd deploy
chmod +x aws.sh
./aws.sh
```

Add the following resources using the AWS web console:
1. Internet facing ALB (choose all three **public subnets** created in above step)
   * Create Target group for ALB with **Target Type** as **IP**
   * Set health check path to `/health`
   * Add security group allowing connections on port 80 from anywhere in the world (0.0.0.0/0)
2. Internal ALB (choose all three **private subnets** created in above step)
   * Create Target group for ALB with **Target Type** as **IP**
   * Set health check path to `/health`
   * Add security group allowing connections on port 80 from security group created in above step.


To deploy the ECS cluster, first add the following files to the `deploy/` folder using the [Service and Task definitions](#service-and-task-definition-files). Fill in the placeholders with the appropriate resource ARNs of resource created in previous steps:
```
deploy/portal-task.json
deploy/hardware-task.json
deploy/portal-service.json
deploy/hardware-service.json
```

Then add a `.env` file to the `deploy/` folder with the following variables (Get the values from AWS web console after having created the VPC, Subnets etc.):
```
export DOCKER_HUB_USER=<dockerhub-username>
export DOCKER_HUB_PASS=<dockerhub-password>

export KEYPAIR=ecs-keypair

export PUB_SUBNET_1=<subnet-id>
export PUB_SUBNET_2=<subnet-id>
export PUB_SUBNET_3=<subnet-id>

export PRIV_SUBNET_1=<subnet-id>
export PRIV_SUBNET_2=<subnet-id>
export PRIV_SUBNET_3=<subnet-id>

export VPC_ID=<vpc-id>

export SG_ID=<security-group-id>
```

Ensure you have the ECS CLI tool installed. Now you can deploy the cluster
```
cd deploy
chmod +x ecs.sh
./ecs.sh
```

## Future Deployments

There's a simple deployment script in the `deploy/` folder called `build-deploy.sh`, which does the following:

1. Build new Docker image with latest code
2. Push image to private registry
3. Update the the task definitions
4. Update the services

This script can be integrated into any CI/CD service and can be triggered to run on PR merge to the repository. Ensure you have the `.env` in the `deploy folder`. Then run it:

```
cd deploy
chmod +x ecs.sh
./build-deploy.sh
```

## Service and Task definition files

The Portal UI task definition (Enter your own ARNs in the placeholders):

```json
{
    "family": "rescale-portal",
    "containerDefinitions": [
      {
        "name": "rescale-portal",
        "image": "kausubmab/rescale-hp:latest",
        "cpu": 128,
        "memoryReservation": 128,
        "command": [
          "portal.py"
        ],
        "portMappings": [
          {
            "containerPort": 5000,
            "hostPort": 5000
          }
        ],
        "secrets": [
          {
            "name": "HARDWARE_HOST",
            "valueFrom": "arn:aws:ssm:<regsion>:<account-id>:parameter/rescale/HARDWARE_HOST"
          },
          {
            "name": "SOCKET_URI",
            "valueFrom": "arn:aws:ssm:<regsion>:<account-id>:parameter/rescale/SOCKET_URI"
          }
        ],
        "essential": true
      }
    ],
    "networkMode": "awsvpc",
    "executionRoleArn": "arn:aws:iam::<account-id>:role/ecs-task-execution-role"
  }
```

The Hardware service task definition (Enter your own ARNs in the placeholders):

```json
{
    "family": "rescale-hardware",
    "containerDefinitions": [
      {
        "name": "rescale-hardware",
        "image": "kausubmab/rescale-hp:latest",
        "cpu": 128,
        "memoryReservation": 128,
        "command": [
          "hardware.py"
        ],
        "portMappings": [
          {
            "containerPort": 5001,
            "hostPort": 5001
          }
        ],
        "secrets": [
          {
            "name": "DB_HOST",
            "valueFrom": "arn:aws:ssm:<regsion>:<account-id>:parameter/rescale/DB_HOST"
          },
          {
            "name": "DB_NAME",
            "valueFrom": "arn:aws:ssm:<regsion>:<account-id>:parameter/rescale/DB_NAME"
          },
          {
            "name": "DB_USER",
            "valueFrom": "arn:aws:ssm:<regsion>:<account-id>:parameter/rescale/DB_USER"
          },
          {
            "name": "DB_PASS",
            "valueFrom": "arn:aws:ssm:<regsion>:<account-id>:parameter/rescale/DB_PASS"
          }
        ],
        "essential": true
      }
    ],
    "networkMode": "awsvpc",
    "executionRoleArn": "arn:aws:iam::<account-id>:role/ecs-task-execution-role"
  }
```

The Portal service definition JSON:

```json
{
    "cluster": "rescale-portal-cluster",
    "serviceName": "rescale-portal",
    "taskDefinition": "rescale-portal",
    "loadBalancers": [
        {
            "targetGroupArn": "arn:aws:elasticloadbalancing:<region>:<account-id>:targetgroup/ecs-target-group/<target-group-id>",
            "containerName": "rescale-portal",
            "containerPort": 5000
        }
    ],
    "desiredCount": 1,
    "networkConfiguration": {
        "awsvpcConfiguration": {
            "subnets": [
                "<subnet-ids>"
            ],
            "securityGroups": [
                "<security-groups>"
            ]
        }
    }
}
```

The Hardware service definition file:

```json
{
    "cluster": "rescale-hardware-cluster",
    "serviceName": "rescale-hardware",
    "taskDefinition": "rescale-hardware",
    "loadBalancers": [
        {
            "targetGroupArn": "arn:aws:elasticloadbalancing:<region>:<account-id>:targetgroup/ecs-target-group/<target-group-id>",
            "containerName": "rescale-hardware",
            "containerPort": 5001
        }
    ],
    "desiredCount": 1,
    "networkConfiguration": {
        "awsvpcConfiguration": {
            "subnets": [
                "<subnet-ids>"
            ],
            "securityGroups": [
                "<security-groups>"
            ]
        }
    }
}
```

## Infrastructure Overview

![alt text](https://www.lucidchart.com/publicSegments/view/4b2d7e2e-246c-42a2-aadf-a0033918a531/image.png "AWS ECS Infrastucture")

1. The public ECS Cluster can be accessed through the internet facing ALB
2. The private ECS cluster can be accessed through the internal ALB (Only resources within the VPC and satisfying the security group constraints can access this ALB)
3. The hardware service runs inside the private cluster
4. The portal UI runs inside the public cluster

I've included screenshots from the AWS web console below:

### ECS Dashboard
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/ECS-dashboard.png "ECS Dashboard")

### Portal Task
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/Portal-task.png "Portal UI Task")

### Hardware Task
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/hardware-task.png "Hardware Task")

### ALBs
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/ALBs.png "Application Load Balancers")

### Target Groups
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/TGs.png "Target Groups")

### ASGs
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/ASGs.png "Auto-Scaling Groups")

### Security Groups
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/Sgs.png "Security Groups")

### EC2
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/EC2.png "EC2 Instances")

### RDS
![alt text](https://rescale-kaushik.s3.us-east-2.amazonaws.com/RDS.png "RDS instance")





