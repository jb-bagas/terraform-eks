# GitHub Actions OIDC provider and environment-scoped Terraform roles.
#
# The role permissions are intentionally broad for a platform Terraform runner:
#   - PowerUserAccess covers VPC, EKS, EC2, KMS, S3, logs, AMP, and Grafana.
#   - IAMFullAccess is required to create/manage the IRSA roles and access entries.
#
# Replace these managed policies with a scoped custom policy or permissions
# boundary before using this role in a shared production account.

locals {
  github_oidc_enabled = var.github_repository != ""
  github_oidc_repos   = local.github_oidc_enabled ? toset(var.github_environments) : toset([])
  github_owner        = local.github_oidc_enabled ? split("/", var.github_repository)[0] : ""
  github_repo_name    = local.github_oidc_enabled ? split("/", var.github_repository)[1] : ""
}

data "aws_partition" "current" {}

data "tls_certificate" "github" {
  count = local.github_oidc_enabled ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = local.github_oidc_enabled ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    data.tls_certificate.github[0].certificates[0].sha1_fingerprint,
    # GitHub's long-standing public OIDC thumbprint, kept as a rotation fallback.
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform-bootstrap"
    Purpose   = "github-actions-oidc"
  }
}

resource "aws_iam_role" "github_actions" {
  for_each = local.github_oidc_repos

  name = "github-actions-${var.project_name}-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github[0].arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # GitHub emits immutable owner/repository IDs in newer subjects, for
        # example repo:owner@123/repo@456:environment:dev. Accept both forms.
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_repository}:environment:${each.key}",
            "repo:${local.github_owner}@*/${local.github_repo_name}@*:environment:${each.key}",
          ]
        }
      }
    }]
  })

  tags = {
    Project     = var.project_name
    Environment = each.key
    ManagedBy   = "terraform-bootstrap"
    Purpose     = "github-actions-terraform"
  }
}

resource "aws_iam_role_policy_attachment" "github_power_user" {
  for_each = local.github_oidc_repos

  role       = aws_iam_role.github_actions[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "github_iam_full" {
  for_each = local.github_oidc_repos

  role       = aws_iam_role.github_actions[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/IAMFullAccess"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form. Leave empty to skip OIDC role creation."
  type        = string
  default     = ""

  validation {
    condition     = var.github_repository == "" || can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be owner/name, or an empty string."
  }
}

variable "github_environments" {
  description = "GitHub environments that receive their own OIDC role and trust policy."
  type        = list(string)
  default     = ["dev", "prod"]

  validation {
    condition     = length(var.github_environments) > 0 && length(distinct(var.github_environments)) == length(var.github_environments)
    error_message = "github_environments must be non-empty and unique."
  }

  validation {
    condition     = alltrue([for env in var.github_environments : can(regex("^[A-Za-z0-9_-]+$", env))])
    error_message = "github_environments may contain only letters, digits, underscores, and hyphens."
  }
}
