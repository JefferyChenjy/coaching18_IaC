output "aws_region" { # -> AWS_REGION
  value = var.aws_region
}

output "ecs_cluster_name" { # -> ECS_CLUSTER
  value = module.ecs.cluster_name
}

output "s3_ecr_repository" { # -> S3_ECR_REPOSITORY (name, not URL)
  value = aws_ecr_repository.app["s3"].name
}

output "sqs_ecr_repository" { # -> SQS_ECR_REPOSITORY
  value = aws_ecr_repository.app["sqs"].name
}

output "s3_ecs_service" { # -> S3_ECS_SERVICE
  value = module.ecs.services["s3-service"].name
}

output "sqs_ecs_service" { # -> SQS_ECS_SERVICE
  value = module.ecs.services["sqs-service"].name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "sqs_queue_url" {
  value = aws_sqs_queue.messages.url
}