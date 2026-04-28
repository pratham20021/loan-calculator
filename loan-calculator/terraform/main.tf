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

# Create a dedicated VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "loan-calculator-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "loan-calculator-igw" }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "loan-calculator-subnet" }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "loan-calculator-rt" }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Security Group: allow SSH (22), HTTP (80), and app port (8080)
resource "aws_security_group" "loan_app_sg" {
  name        = "loan-calculator-sg"
  description = "Allow SSH, HTTP, and app traffic"
  vpc_id      = aws_vpc.main.id

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
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.loan_app_key.key_name
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.loan_app_sg.id]
  associate_public_ip_address = true

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
