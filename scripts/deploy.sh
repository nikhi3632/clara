#!/bin/bash
set -e

AWS_REGION="us-east-1"
ECR_REPO="clara-agent"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "Building Docker image..."
docker build -t ${ECR_REPO} ./backend

echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}

echo "Tagging and pushing image..."
docker tag ${ECR_REPO}:latest ${ECR_URL}:latest
docker push ${ECR_URL}:latest

echo "Restarting EC2 agent..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=clara-agent" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

aws ssm send-command \
  --instance-ids ${INSTANCE_ID} \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"docker pull ${ECR_URL}:latest\", \"docker stop clara-agent || true\", \"docker rm clara-agent || true\", \"docker run -d --restart always --name clara-agent -p 8080:8080 -e AWS_REGION=us-east-1 --log-driver=awslogs --log-opt awslogs-region=us-east-1 --log-opt awslogs-group=/clara/agent ${ECR_URL}:latest\"]"

echo "Deployed!"
