variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "docker_image" {
  description = "Docker Hub image name (e.g., yourdockerhubuser/loan-calculator:latest)"
  type        = string
}

variable "app_port" {
  description = "Port the application runs on"
  type        = number
  default     = 8080
}
