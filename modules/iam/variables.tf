variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the cluster"
  type        = string
}

variable "secrets_manager_secret_arns" {
  description = "Secrets Manager secret ARNs the CSI provider may read. Restrict this in production."
  type        = list(string)
  default     = ["*"]
}

variable "tags" {
  description = "Tags applied to IAM resources"
  type        = map(string)
}
