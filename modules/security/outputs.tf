output "kms_key_arn" {
  value       = aws_kms_key.eks.arn
  description = "KMS key ARN used for EKS secret encryption"
}

output "kms_key_alias" {
  value       = aws_kms_alias.eks.name
  description = "KMS alias for the EKS secret encryption key"
}
