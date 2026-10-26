output "cluster_name" {
  value       = module.eks.cluster_name
  description = "The name of the EKS cluster"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "The endpoint for the EKS cluster"
}

output "cluster_version" {
  value       = module.eks.cluster_version
  description = "The Kubernetes version of the EKS cluster"
}

output "configure_kubectl" {
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
  description = "Command to configure kubectl for the cluster"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "Private subnet IDs used by EKS"
}

output "kms_key_arn" {
  value       = module.security.kms_key_arn
  description = "KMS key used for EKS secret encryption"
}

output "oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "IAM OIDC provider ARN used for IRSA"
}

output "amp_workspace_arn" {
  value       = module.addons.amp_workspace_arn
  description = "Amazon Managed Prometheus workspace ARN"
}

output "amp_workspace_endpoint" {
  value       = module.addons.amp_workspace_endpoint
  description = "Amazon Managed Prometheus remote-write endpoint"
}

output "amg_workspace_url" {
  value       = module.addons.amg_workspace_url
  description = "Amazon Managed Grafana workspace URL"
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS region used by this environment"
}
