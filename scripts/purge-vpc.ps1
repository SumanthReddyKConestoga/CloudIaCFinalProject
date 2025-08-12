Param(
  [Parameter(Mandatory=$true)][string]$VpcId,
  [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
Write-Host ">>> Purging VPC $VpcId in $Region ..." -ForegroundColor Yellow

# Safety: never delete default VPC
$default = (aws ec2 describe-vpcs --vpc-ids $VpcId --region $Region --query "Vpcs[0].IsDefault" --output text)
if ($default -eq "True") { throw "Refusing to delete the DEFAULT VPC: $VpcId" }

# 1) Terminate EC2 instances
$instances = (aws ec2 describe-instances --filters Name=vpc-id,Values=$VpcId --region $Region --query "Reservations[].Instances[].InstanceId" --output text)
if ($instances) {
  aws ec2 terminate-instances --instance-ids $instances --region $Region | Out-Null
  try { aws ec2 wait instance-terminated --instance-ids $instances --region $Region } catch {}
}

# 2) Delete NAT Gateways (wait)
$natIds = (aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$VpcId --region $Region --query "NatGateways[].NatGatewayId" --output text)
if ($natIds) {
  $natIds.Split() | ForEach-Object { aws ec2 delete-nat-gateway --nat-gateway-id $_ --region $Region | Out-Null }
  try { aws ec2 wait nat-gateway-deleted --nat-gateway-ids $natIds --region $Region } catch {}
}

# 3) Delete VPC endpoints
$vpceIds = (aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VpcId --region $Region --query "VpcEndpoints[].VpcEndpointId" --output text)
if ($vpceIds) { aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $vpceIds --region $Region | Out-Null }

# 4) Disassociate EIPs and clean ENIs
$eniIds = (aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=$VpcId --region $Region --query "NetworkInterfaces[].NetworkInterfaceId" --output text)
if ($eniIds) {
  $eniIds.Split() | ForEach-Object {
    $assocIds = (aws ec2 describe-addresses --filters Name=network-interface-id,Values=$_ --region $Region --query "Addresses[].AssociationId" --output text)
    if ($assocIds) { $assocIds.Split() | ForEach-Object { aws ec2 disassociate-address --association-id $_ --region $Region | Out-Null } }
    $allocIds = (aws ec2 describe-addresses --filters Name=network-interface-id,Values=$_ --region $Region --query "Addresses[].AllocationId" --output text)
    if ($allocIds) { $allocIds.Split() | ForEach-Object { aws ec2 release-address --allocation-id $_ --region $Region | Out-Null } }
    $attId = (aws ec2 describe-network-interfaces --network-interface-ids $_ --region $Region --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text)
    if ($attId -and $attId -ne "None") { aws ec2 detach-network-interface --attachment-id $attId --region $Region | Out-Null }
  }
  $eniAvail = (aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=$VpcId Name=status,Values=available --region $Region --query "NetworkInterfaces[].NetworkInterfaceId" --output text)
  if ($eniAvail) { $eniAvail.Split() | ForEach-Object { aws ec2 delete-network-interface --network-interface-id $_ --region $Region | Out-Null } }
}

# 5) Detach & delete IGWs
$igws = (aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VpcId --region $Region --query "InternetGateways[].InternetGatewayId" --output text)
if ($igws) {
  $igws.Split() | ForEach-Object {
    aws ec2 detach-internet-gateway --internet-gateway-id $_ --vpc-id $VpcId --region $Region | Out-Null
    aws ec2 delete-internet-gateway --internet-gateway-id $_ --region $Region | Out-Null
  }
}

# 6) Disassociate non-main RTs, then delete them
$assocNonMain = (aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VpcId --region $Region --query "RouteTables[].Associations[?Main==`false`].RouteTableAssociationId" --output text)
if ($assocNonMain) { $assocNonMain.Split() | ForEach-Object { aws ec2 disassociate-route-table --association-id $_ --region $Region | Out-Null } }
$rtIds = (aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VpcId Name=association.main,Values=false --region $Region --query "RouteTables[].RouteTableId" --output text)
if ($rtIds) { $rtIds.Split() | ForEach-Object { try { aws ec2 delete-route-table --route-table-id $_ --region $Region | Out-Null } catch {} } }

# 7) Delete subnets
$subnets = (aws ec2 describe-subnets --filters Name=vpc-id,Values=$VpcId --region $Region --query "Subnets[].SubnetId" --output text)
if ($subnets) { $subnets.Split() | ForEach-Object { aws ec2 delete-subnet --subnet-id $_ --region $Region | Out-Null } }

# 8) Delete non-default SGs
$sgs = (aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VpcId --region $Region --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
if ($sgs) { $sgs.Split() | ForEach-Object { try { aws ec2 delete-security-group --group-id $_ --region $Region | Out-Null } catch {} } }

# 9) Delete non-default NACLs
$nacls = (aws ec2 describe-network-acls --filters Name=vpc-id,Values=$VpcId Name=default,Values=false --region $Region --query "NetworkAcls[].NetworkAclId" --output text)
if ($nacls) { $nacls.Split() | ForEach-Object { aws ec2 delete-network-acl --network-acl-id $_ --region $Region | Out-Null } }

# 10) Delete VPC
aws ec2 delete-vpc --vpc-id $VpcId --region $Region | Out-Null
Write-Host ">>> Purge complete for $VpcId" -ForegroundColor Green
