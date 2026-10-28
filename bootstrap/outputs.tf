output "state_bucket_name" {
  description = "The name of the S3 bucket used for Terraform state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  description = "The ARN of the state bucket"
  value       = aws_s3_bucket.tfstate.arn
}

output "log_bucket_name" {
  description = "The optional access-log bucket name"
  value       = try(aws_s3_bucket.logs[0].bucket, null)
}

output "backend_configuration" {
  description = "Copy this into your backend/*.tfbackend files"
  value = {
    bucket       = aws_s3_bucket.tfstate.bucket
    region       = var.region
    encrypt      = true
    use_lockfile = true
  }
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN, or null when OIDC is disabled"
  value       = try(aws_iam_openid_connect_provider.github[0].arn, null)
}

output "github_oidc_role_arns" {
  description = "Map of GitHub environment name to Terraform OIDC role ARN"
  value = {
    for env, role in aws_iam_role.github_actions : env => role.arn
  }
}
