output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.loan_app.public_ip
}

output "app_url" {
  description = "URL to access the application"
  value       = "http://${aws_instance.loan_app.public_ip}:${var.app_port}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${path.module}/loan-calculator-key.pem ec2-user@${aws_instance.loan_app.public_ip}"
}

output "private_key_path" {
  description = "Path to the generated private key file"
  value       = "${path.module}/loan-calculator-key.pem"
}
