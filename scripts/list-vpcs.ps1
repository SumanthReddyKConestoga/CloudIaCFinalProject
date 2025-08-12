Param([string]$Region = "us-east-1")

aws ec2 describe-vpcs --region $Region `
  --query "Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,IsDefault:IsDefault,Name:Tags[?Key=='Name']|[0].Value}" `
  --output table
