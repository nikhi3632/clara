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

# Clean up old images, pull new one, and restart container
aws ssm send-command \
  --instance-ids ${INSTANCE_ID} \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    \"echo 'Cleaning up old Docker images...'\",
    \"docker system prune -af --filter 'until=24h'\",
    \"echo 'Logging into ECR...'\",
    \"aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_URL}\",
    \"echo 'Pulling new image...'\",
    \"docker pull ${ECR_URL}:latest\",
    \"echo 'Restarting container...'\",
    \"docker stop clara-agent || true\",
    \"docker rm clara-agent || true\",
    \"docker run -d --restart unless-stopped --name clara-agent -p 8081:8081 -e AWS_REGION=us-east-1 -e CALL_REDIRECT_ENABLED=false --log-driver=awslogs --log-opt awslogs-region=us-east-1 --log-opt awslogs-group=/ecs/clara-agent ${ECR_URL}:latest\",
    \"echo 'Deploy complete'\",
    \"docker ps --format '{{.Names}} {{.Status}}'\"
  ]"

echo "Deployed!"
