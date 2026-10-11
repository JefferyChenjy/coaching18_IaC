variable "environment" {
  description = "The environment for the deployment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "The name of the project"
  type        = string
  default     = "coaching-18"
}

variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "github_repository_username" {
  description = "The GitHub username or organization that owns the repositories"
  type        = string
  default     = "JefferyChenjy"
}

variable "github_repository_names" {
  description = "A list of GitHub repository names to be used for OIDC setup"
  type        = list(string)
  default     = ["coaching18_IaC", "coaching18"]
}

variable "github_oidc_role_name" {
  description = "Name of the GitHub OIDC role your teammate created with github-oidc-boostrap"
  type        = string
  default     = "" # ask your teammate what he set github_oidc_role_name to
}