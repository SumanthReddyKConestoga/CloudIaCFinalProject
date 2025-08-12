output "s3_bucket_names" {
  description = "Created S3 bucket names"
  value       = [for b in aws_s3_bucket.buckets : b.bucket]
}

output "ec2_public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.ec2.public_ip
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.mysql.address
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}
