# Global
variable "project_name" {
  description = "Project identifier (e.g., sumanth9040660)"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# S3
variable "s3_bucket_suffixes" {
  description = "Four suffixes to build bucket names"
  type        = list(string)
  default     = ["data", "logs", "backup", "artifacts"]
}

# Networking
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.50.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.50.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "Two private subnets for RDS (different AZs recommended)"
  type        = list(string)
  default     = ["10.50.11.0/24", "10.50.12.0/24"]
}

variable "ec2_ssh_cidr" {
  description = "CIDR allowed for SSH to EC2 (use your IP /32)"
  type        = string
  default     = "0.0.0.0/0"
}

# EC2
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 Key Pair name (optional)"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "Optional AMI ID override (if empty, pick latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

# RDS
variable "db_name" {
  description = "DB name"
  type        = string
  default     = "assignmentdb"
}

variable "db_username" {
  description = "Master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "RDS storage GB"
  type        = number
  default     = 20
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0.35"
}
