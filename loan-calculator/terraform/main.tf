terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use default VPC to keep it simple
data "aws_vpc" "default" {
  default = true
}

# Security Group: allow SSH (22), HTTP (80), and app port (8080)
resource "aws_security_group" "loan_app_sg" {
  name        = "loan-calculator-sg"
  description = "Allow SSH, HTTP, and app traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App Port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "loan-calculator-sg"
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Generate RSA private key
resource "tls_private_key" "loan_app_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair from generated public key
resource "aws_key_pair" "loan_app_key" {
  key_name   = "loan-calculator-key"
  public_key = tls_private_key.loan_app_key.public_key_openssh
}

# Save private key to local .pem file
resource "local_file" "private_key" {
  content         = tls_private_key.loan_app_key.private_key_pem
  filename        = "${path.module}/loan-calculator-key.pem"
  file_permission = "0400"
}

# EC2 Instance
resource "aws_instance" "loan_app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.loan_app_key.key_name
  vpc_security_group_ids = [aws_security_group.loan_app_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    # Install Docker
    dnf update -y
    dnf install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    # Pull and run the Docker container
    docker pull ${var.docker_image}
    docker run -d \
      --name loan-calculator \
      --restart always \
      -p ${var.app_port}:${var.app_port} \
      ${var.docker_image}
  EOF

  tags = {
    Name = "loan-calculator-server"
  }
}
