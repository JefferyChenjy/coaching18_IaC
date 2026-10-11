# Current AWS account (used to make the S3 bucket name unique)
data "aws_caller_identity" "current" {}

# Look up the first hardcoded subnet only to get its VPC ID
data "aws_subnet" "ecs" {
  id = local.subnet_ids[0]
}

