Absolutely, Sumanth. Here’s the **lean, no-nonsense README**: only what matters, zero config dumps, heavy on **commands**, and explicit **screenshot** capture guidance. Use it as your repo README or as your submission playbook.

---

# CloudIaCFinalProject — Operator Runbook

This project deploys **S3, EC2, RDS** on AWS using **Terraform** (private RDS) and **CloudFormation** (public RDS). Follow this runbook end-to-end for your demo and evidence.

---

# 1) Minimal repo map

```
CloudIaCFinalProject/
├─ terraform/           # IaC with outputs
├─ cloudformation/      # s3.yaml, ec2.yaml, rds.yaml
└─ scripts/             # set-aws-env.ps1, (optional) CFN helpers
```

---

# 2) One-time setup (per shell)

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\set-aws-env.ps1
aws sts get-caller-identity
```

✅ **Expected:** Account/Arn/UserId JSON.

---

# 3) Terraform — deploy & outputs

```powershell
cd .\terraform\
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform output
```

✅ **Expected outputs:**

* `ec2_public_ip` → IPv4
* `rds_endpoint`  → DNS name (private)
* `s3_bucket_names` → 4 names
* `vpc_id` → vpc-\*

**Screenshots to take (Console):**

* S3 → **Buckets** → 4 TF buckets → each: **Properties → Bucket Versioning = Enabled**
* EC2 → **Instances** → TF instance → **Public IPv4 address present**
* RDS → **Databases** → TF DB → **Publicly accessible = No**; copy **Endpoint**
* VPC → **Your VPCs** → TF VPC present

---

# 4) CloudFormation — deploy 3 stacks

## 4.1 S3 (3 buckets)

```powershell
$suf=$(Get-Random -Maximum 99999); aws cloudformation deploy --region us-east-1 --stack-name "sumanth9040660-s3" --template-file ".\cloudformation\s3.yaml" --parameter-overrides BucketAName="sumanth9040660-cf-a-$suf" BucketBName="sumanth9040660-cf-b-$suf" BucketCName="sumanth9040660-cf-c-$suf"
```

## 4.2 EC2 (latest AL2023)

```powershell
$ami=$(aws ec2 describe-images --region us-east-1 --owners amazon --filters "Name=name,Values=al2023-ami-*-x86_64" --query "sort_by(Images,&CreationDate)[-1].ImageId" --output text); aws cloudformation deploy --region us-east-1 --stack-name "sumanth9040660-ec2" --template-file ".\cloudformation\ec2.yaml" --parameter-overrides AmiId="$ami" InstanceType="t3.micro" KeyName="" VpcCidr="10.60.0.0/16" PublicSubnetCidr="10.60.1.0/24" AllowSshCidr="0.0.0.0/0"
```

## 4.3 RDS (public — assignment only)

```powershell
aws cloudformation deploy --region us-east-1 --stack-name "sumanth9040660-rds" --template-file ".\cloudformation\rds.yaml" --parameter-overrides DBName="assignment3" DBUsername="adminuser" DBPassword="ChangeMe_Complex#123" EngineVersion="8.0"
```

---

# 5) Validation — CLI one-liners (copy/paste)

## 5.1 Terraform validation

```powershell
cd .\terraform; terraform output
cd .\terraform; terraform output -raw ec2_public_ip
cd .\terraform; terraform output -raw rds_endpoint
cd .\terraform; terraform output -json s3_bucket_names
cd .\terraform; terraform output -raw vpc_id
```

## 5.2 CloudFormation outputs

```powershell
aws cloudformation describe-stacks --region us-east-1 --stack-name "sumanth9040660-s3"  --query "Stacks[0].Outputs" --output table
aws cloudformation describe-stacks --region us-east-1 --stack-name "sumanth9040660-ec2" --query "Stacks[0].Outputs" --output table
aws cloudformation describe-stacks --region us-east-1 --stack-name "sumanth9040660-rds" --query "Stacks[0].Outputs" --output table
```

## 5.3 S3 versioning proof

**Terraform buckets:**

```powershell
cd .\terraform; (terraform output -json s3_bucket_names | ConvertFrom-Json) | % { "$_ : $(aws s3api get-bucket-versioning --bucket $_ --query Status --output text)" }
```

**CloudFormation buckets:**

```powershell
$cfnb=(aws cloudformation describe-stacks --region us-east-1 --stack-name "sumanth9040660-s3" --query "Stacks[0].Outputs[*].OutputValue" --output text).Split(); $cfnb | % { "$_ : $(aws s3api get-bucket-versioning --bucket $_ --query Status --output text)" }
```

✅ **Expected:** `Enabled` for all.

## 5.4 EC2 detail checks

**Terraform EC2 by public IP:**

```powershell
$ip=(cd .\terraform; terraform output -raw ec2_public_ip); aws ec2 describe-instances --filters Name=ip-address,Values=$ip --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,SubnetId,SecurityGroups[].GroupId]" --output table
```

**CFN EC2 by tag:**

```powershell
aws ec2 describe-instances --filters Name=tag:Name,Values=cf-ec2-instance --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,SubnetId]" --output table
```

✅ **Expected:** `running`, `PublicIpAddress` present.

## 5.5 RDS detail checks

**Terraform RDS (private):**

```powershell
aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, 'mysql')].[DBInstanceIdentifier,DBInstanceStatus,PubliclyAccessible,Engine,EngineVersion]" --output table
```

**CFN RDS (public):**

```powershell
aws rds describe-db-instances --db-instance-identifier cf-public-mysql --query "DBInstances[0].[DBInstanceStatus,PubliclyAccessible,Endpoint.Address]" --output table
```

✅ **Expected:** TF: `PubliclyAccessible = False`. CFN: `PubliclyAccessible = True`.

## 5.6 VPC sanity

```powershell
cd .\terraform; $vpc=(terraform output -raw vpc_id); aws ec2 describe-vpcs --vpc-ids $vpc --query "Vpcs[0].[VpcId,CidrBlock,IsDefault]" --output table
aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc --query "Subnets[].[SubnetId,CidrBlock,MapPublicIpOnLaunch]" --output table
```

---

# 6) Screenshot checklist (what/where)

* **Terraform CLI**:

  * `terraform output` (full)
  * `terraform plan` summary (last lines)
  * `terraform apply` completion (Added/Changed/Destroyed line)

* **S3 Console**:

  * 4 **Terraform** buckets → each bucket **Properties → Bucket Versioning = Enabled** (one screenshot with 4 tiles is fine; open one bucket’s Versioning panel for proof)
  * 3 **CloudFormation** buckets (names from `*-s3` outputs)

* **EC2 Console**:

  * **TF EC2**: details pane showing **Public IPv4**
  * **CFN EC2**: details pane showing **Public IPv4** + **Tags(Name=cf-ec2-instance)**

* **RDS Console**:

  * **TF DB**: **Publicly accessible = No**, **Endpoint** visible
  * **CFN DB**: **Publicly accessible = Yes**, **Endpoint** visible

* **CloudFormation Console**:

  * Stacks list with `sumanth9040660-s3`, `-ec2`, `-rds` = **CREATE\_COMPLETE**
  * For `-ec2`: **Outputs** tab showing **PublicIp**
  * For `-rds`: **Outputs** tab showing **RdsEndpoint**

* **VPC Console**:

  * **Your VPCs** → TF VPC selected (ID from `terraform output`)
  * **Subnets** (3 subnets: 1 public + 2 private) — list view is fine

---

```powershell
cd .\terraform; terraform init; terraform plan -out=tfplan; terraform apply -auto-approve tfplan; terraform output
```



---

# 8) Cleanup (responsible teardown)

**Terraform:**

```powershell
cd .\terraform; terraform destroy -auto-approve
```

**CloudFormation:**

```powershell
aws cloudformation delete-stack --region us-east-1 --stack-name "sumanth9040660-rds"
aws cloudformation delete-stack --region us-east-1 --stack-name "sumanth9040660-ec2"
aws cloudformation delete-stack --region us-east-1 --stack-name "sumanth9040660-s3"
```

---

# 9) Fast fixes (if things wobble)

* **Stack in `ROLLBACK_COMPLETE`** → delete & redeploy:

```powershell
aws cloudformation delete-stack --region us-east-1 --stack-name "<name>"; aws cloudformation wait stack-delete-complete --region us-east-1 --stack-name "<name>"
```

* **Engine version not found** (RDS):

```powershell
aws rds describe-db-engine-versions --region us-east-1 --engine mysql --query "reverse(sort_by(DBEngineVersions[?starts_with(EngineVersion, '8.0')],&EngineVersion))[0].EngineVersion" --output text
```

* **VPC quota exceeded** (rare in labs): delete unused non-default VPCs (Console → VPC → Delete VPC with dependencies).



