# AWS provider uses the env vars you set with set-aws-env.ps1
provider "aws" {
  region = var.region
}
