output "alb_controller_role_arn" {
  value       = module.alb_controller_irsa.iam_role_arn
  description = "IRSA role ARN for the AWS Load Balancer Controller"
}

output "secrets_csi_role_arn" {
  value       = module.secrets_csi_irsa.iam_role_arn
  description = "IRSA role ARN for the Secrets Store CSI AWS provider"
}

output "adot_collector_role_arn" {
  value       = module.adot_collector_irsa.iam_role_arn
  description = "IRSA role ARN for the ADOT Collector"
}

output "ebs_csi_role_arn" {
  value       = module.ebs_csi_irsa.iam_role_arn
  description = "IRSA role ARN for the EBS CSI driver"
}

output "cluster_autoscaler_role_arn" {
  value       = module.cluster_autoscaler_irsa.iam_role_arn
  description = "IRSA role ARN for the Cluster Autoscaler"
}
