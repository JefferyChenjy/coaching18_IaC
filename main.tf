locals {
  name_prefix = "coaching18-iac" # lowercase: ECR repo names must be lowercase

  # One ECR repo per app
  apps = toset(["s3", "sqs"])

  # Hardcoded subnets (default VPC). Both must be in the same VPC. public subnet
  subnet_ids = ["subnet-00b4c98869b996d86", "subnet-07fe08d5909e677db"]
}

resource "aws_security_group" "ecs" {
  name   = "${local.name_prefix}-ecs-sg"
  vpc_id = data.aws_subnet.ecs.vpc_id

  ingress {
    description = "S3 app"
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SQS app"
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# ECR: one repo per app. MUTABLE because the app pipeline re-pushes :latest.
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  for_each = local.apps

  name                 = "${local.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# ---------------------------------------------------------------------------
# S3 bucket the S3 app uploads into (account ID keeps the name globally unique)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "uploads" {
  bucket        = "${local.name_prefix}-uploads-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# ---------------------------------------------------------------------------
# SQS queue the SQS app sends messages into
# ---------------------------------------------------------------------------
resource "aws_sqs_queue" "messages" {
  name                      = "${local.name_prefix}-messages"
  message_retention_seconds = 345600 # 4 days
  sqs_managed_sse_enabled   = true
}

# ---------------------------------------------------------------------------
# ECS cluster + 2 services
# ---------------------------------------------------------------------------
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 7.5.0"

  cluster_name               = "${local.name_prefix}-ecs-cluster"
  cluster_capacity_providers = ["FARGATE"]

  services = {
    s3-service = {
      cpu    = 512
      memory = 1024
      runtime_platform = {
        operating_system_family = "LINUX"
        cpu_architecture        = "X86_64" # GitHub ubuntu-latest runners build amd64 images
      }

      container_definitions = {
        s3-app = {
          essential              = true
          image                  = "${aws_ecr_repository.app["s3"].repository_url}:latest"
          readonlyRootFilesystem = false # Flask spools larger uploads to /tmp
          portMappings = [
            { containerPort = 5001, protocol = "tcp" }
          ]
          environment = [
            { name = "AWS_REGION", value = var.aws_region },
            { name = "BUCKET_NAME", value = aws_s3_bucket.uploads.bucket },
          ]
        }
      }

      # Task role: what the app itself may do in AWS
      tasks_iam_role_statements = [
        {
          actions   = ["s3:PutObject"]
          resources = ["${aws_s3_bucket.uploads.arn}/*"]
        }
      ]

      assign_public_ip      = true
      subnet_ids            = local.subnet_ids
      security_group_ids    = [aws_security_group.ecs.id]
      create_security_group = false
    }

    sqs-service = {
      # The SQS pipeline registers its own task definition revisions (image :<sha>),
      # so Terraform must not roll the service back to its own revision.
      # Set this BEFORE the first apply — changing it later recreates the service.
      ignore_task_definition_changes = true

      cpu    = 512
      memory = 1024
      runtime_platform = {
        operating_system_family = "LINUX"
        cpu_architecture        = "X86_64"
      }

      container_definitions = {
        sqs-app = {
          essential = true
          image     = "${aws_ecr_repository.app["sqs"].repository_url}:latest"
          portMappings = [
            { containerPort = 5002, protocol = "tcp" }
          ]
          environment = [
            { name = "AWS_REGION", value = var.aws_region },
            { name = "QUEUE_URL", value = aws_sqs_queue.messages.url },
          ]
        }
      }

      tasks_iam_role_statements = [
        {
          actions   = ["sqs:SendMessage"]
          resources = [aws_sqs_queue.messages.arn]
        }
      ]

      assign_public_ip      = true
      subnet_ids            = local.subnet_ids
      security_group_ids    = [aws_security_group.ecs.id]
      create_security_group = false
    }
  }
}
