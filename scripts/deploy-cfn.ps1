Param(
  [string]$Region = "us-east-1",
  [string]$Prefix = "sumanth9040660"
)

# Unique suffix for S3 names (global namespace)
$SUF = (Get-Random -Maximum 99999)

Write-Host "Region: $Region  Prefix: $Prefix  Suffix: $SUF"

# Resolve latest AL2023 AMI in region
$AMI = aws ec2 describe-images `
  --region $Region `
  --owners amazon `
  --filters "Name=name,Values=al2023-ami-*-x86_64" `
  --query "sort_by(Images,&CreationDate)[-1].ImageId" `
  --output text

Write-Host "Using AMI: $AMI"

# --- S3 stack ---
aws cloudformation deploy `
  --region $Region `
  --stack-name "$Prefix-s3" `
  --template-file ".\cloudformation\s3.yaml" `
  --parameter-overrides `
    BucketAName="$Prefix-cf-a-$SUF" `
    BucketBName="$Prefix-cf-b-$SUF" `
    BucketCName="$Prefix-cf-c-$SUF"

# --- EC2 stack ---
# (Optionally lock SSH to your IP: set $MYIP = "<YOUR.IP>/32")
$MYIP = "0.0.0.0/0"

aws cloudformation deploy `
  --region $Region `
  --stack-name "$Prefix-ec2" `
  --template-file ".\cloudformation\ec2.yaml" `
  --parameter-overrides `
    AmiId="$AMI" `
    InstanceType="t3.micro" `
    KeyName="" `
    VpcCidr="10.60.0.0/16" `
    PublicSubnetCidr="10.60.1.0/24" `
    AllowSshCidr="$MYIP"

# --- RDS stack (public for assignment only) ---
aws cloudformation deploy `
  --region $Region `
  --stack-name "$Prefix-rds" `
  --template-file ".\cloudformation\rds.yaml" `
  --parameter-overrides `
    DBName="assignment3" `
    DBUsername="adminuser" `
    DBPassword="ChangeMe_Complex#123" `
    EngineVersion="8.0"

Write-Host "CFN deploy complete."
