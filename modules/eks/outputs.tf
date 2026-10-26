output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_version" {
  description = "The Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The OIDC Issuer URL for the cluster (used for IRSA)"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the cluster's IAM OIDC provider"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "vpc_cni_role_arn" {
  description = "IRSA role ARN used by the VPC CNI add-on"
  value       = aws_iam_role.vpc_cni.arn
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}
