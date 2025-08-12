############################################################
# Locals & helpers
############################################################
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# Ensure globally-unique S3 names
resource "random_string" "s3" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

# Use two distinct AZs for private subnets
data "aws_availability_zones" "available" {
  state = "available"
}

############################################################
# S3 – 4 private, versioned buckets
############################################################
resource "aws_s3_bucket" "buckets" {
  for_each = toset(var.s3_bucket_suffixes)

  bucket = "${local.name_prefix}-${each.value}-${random_string.s3.id}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "Sumanth9040660"
    Purpose     = "Terraform-S3"
  }
}

resource "aws_s3_bucket_public_access_block" "pab" {
  for_each = aws_s3_bucket.buckets

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "ver" {
  for_each = aws_s3_bucket.buckets

  bucket = each.value.id
  versioning_configuration { status = "Enabled" }
}

############################################################
# Networking – VPC + public subnet + two private subnets
############################################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "${local.name_prefix}-public-a" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route" "default_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  for_each = {
    a = { cidr = var.private_subnet_cidrs[0], az = data.aws_availability_zones.available.names[1] }
    b = { cidr = var.private_subnet_cidrs[1], az = data.aws_availability_zones.available.names[2] }
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = "${local.name_prefix}-private-${each.key}" }
}

############################################################
# EC2 – SG + instance with public IP
############################################################
resource "aws_security_group" "ec2_sg" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Allow SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ec2_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-ec2-sg" }
}

# Latest Amazon Linux 2023 if no AMI provided
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "ec2" {
  ami                         = coalesce(var.ami_id, data.aws_ami.al2023.id)
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  key_name                    = length(var.key_name) > 0 ? var.key_name : null

  tags = {
    Name        = "${local.name_prefix}-ec2"
    Environment = var.environment
  }
}

############################################################
# RDS – private, reachable from EC2 SG only
############################################################
resource "aws_db_subnet_group" "dbsg" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags       = { Name = "${local.name_prefix}-db-subnets" }
}

resource "aws_security_group" "rds_sg" {
  name   = "${local.name_prefix}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2 SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-rds-sg" }
}

resource "aws_db_instance" "mysql" {
  identifier              = "${local.name_prefix}-mysql"
  engine                  = "mysql"
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.dbsg.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  multi_az                = false
  publicly_accessible     = false         # safer (TF track)
  storage_encrypted       = true
  skip_final_snapshot     = true          # demo
  deletion_protection     = false
  backup_retention_period = 0

  depends_on = [aws_db_subnet_group.dbsg]
  tags = {
    Name        = "${local.name_prefix}-mysql"
    Environment = var.environment
  }
}
