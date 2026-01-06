# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# Provider (uses AWS CLI credentials automatically)
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "clara"
      ManagedBy = "terraform"
    }
  }
}

# ECR
resource "aws_ecr_repository" "clara" {
  name                 = "clara-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# VPC
resource "aws_vpc" "clara" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "clara-vpc" }
}

resource "aws_subnet" "clara" {
  vpc_id                  = aws_vpc.clara.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "clara-subnet" }
}

resource "aws_internet_gateway" "clara" {
  vpc_id = aws_vpc.clara.id
}

resource "aws_route_table" "clara" {
  vpc_id = aws_vpc.clara.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.clara.id
  }
}

resource "aws_route_table_association" "clara" {
  subnet_id      = aws_subnet.clara.id
  route_table_id = aws_route_table.clara.id
}

# Security Group
resource "aws_security_group" "clara" {
  name   = "clara-agent-sg"
  vpc_id = aws_vpc.clara.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM
resource "aws_iam_role" "clara" {
  name = "clara-agent-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.clara.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.clara.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.clara.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ssm_params" {
  name = "clara-ssm-params"
  role = aws_iam_role.clara.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/clara/*"
    }]
  })
}

resource "aws_iam_instance_profile" "clara" {
  name = "clara-agent-profile"
  role = aws_iam_role.clara.name
}

# CloudWatch
resource "aws_cloudwatch_log_group" "clara" {
  name              = "/clara/agent"
  retention_in_days = 7
}

# EC2
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "clara" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.clara.id
  vpc_security_group_ids = [aws_security_group.clara.id]
  iam_instance_profile   = aws_iam_instance_profile.clara.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io awscli
    systemctl enable docker
    systemctl start docker

    # Set up daily Docker cleanup cron job (runs at 3 AM UTC)
    echo "0 3 * * * root docker system prune -af --filter 'until=48h' >> /var/log/docker-cleanup.log 2>&1" > /etc/cron.d/docker-cleanup
    chmod 644 /etc/cron.d/docker-cleanup

    # Pull and run the agent
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.clara.repository_url}
    docker pull ${aws_ecr_repository.clara.repository_url}:latest
    docker run -d --restart unless-stopped --name clara-agent -p 8081:8081 \
      -e AWS_REGION=${var.aws_region} \
      -e CALL_REDIRECT_ENABLED=false \
      --log-driver=awslogs --log-opt awslogs-region=${var.aws_region} --log-opt awslogs-group=/ecs/clara-agent \
      ${aws_ecr_repository.clara.repository_url}:latest
  EOF

  tags = { Name = "clara-agent" }
}

# Monitoring
resource "aws_sns_topic" "alerts" {
  name = "clara-alerts"
}

resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "clara-error-filter"
  pattern        = "{ $.level = \"error\" }"
  log_group_name = aws_cloudwatch_log_group.clara.name
  metric_transformation {
    name      = "ErrorCount"
    namespace = "Clara/Agent"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "agent_errors" {
  alarm_name          = "clara-agent-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "Clara/Agent"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Agent errors exceeded threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { LogGroup = "/clara/agent" }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "clara-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU utilization above 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { InstanceId = aws_instance.clara.id }
}

# Outputs
output "ecr_repository_url" { value = aws_ecr_repository.clara.repository_url }
output "instance_public_ip" { value = aws_instance.clara.public_ip }
output "instance_id" { value = aws_instance.clara.id }
