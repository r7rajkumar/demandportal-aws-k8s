variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "cloudrequest"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "Existing VPC ID to deploy into"
  type        = string
  # Set this in terraform.tfvars
}

variable "your_ip_cidr" {
  description = "Your IP in CIDR notation for SSH access e.g. 1.2.3.4/32"
  type        = string
  # Set this in terraform.tfvars
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "master_instance_type" {
  description = "EC2 instance type for master node"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}
