# Non-sensitive demo values (OK to commit)
project_name           = "sumanth9040660"
environment            = "dev"
region                 = "us-east-1"

# Lock SSH to your IP before demo (use 0.0.0.0/0 only for quick tests)
ec2_ssh_cidr           = "0.0.0.0/0"

instance_type          = "t3.micro"
key_name               = ""
ami_id                 = ""

db_name                = "assignment3"
db_username            = "adminuser"
db_password            = "REPLACE_ME_LOCALLY"
db_allocated_storage   = 20
db_instance_class      = "db.t3.micro"
db_engine_version      = "8.0"

vpc_cidr               = "10.50.0.0/16"
public_subnet_cidr     = "10.50.1.0/24"
private_subnet_cidrs   = ["10.50.11.0/24", "10.50.12.0/24"]

s3_bucket_suffixes     = ["data", "logs", "backup", "artifacts"]
