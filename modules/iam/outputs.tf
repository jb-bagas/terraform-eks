output "alb_controller_role_arn" { value = module.alb_controller_irsa.iam_role_arn }
output "secrets_csi_role_arn" { value = module.secrets_csi_irsa.iam_role_arn }
output "adot_collector_role_arn" { value = module.adot_collector_irsa.iam_role_arn }
output "ebs_csi_role_arn" { value = module.ebs_csi_irsa.iam_role_arn }
output "cluster_autoscaler_role_arn" { value = module.cluster_autoscaler_irsa.iam_role_arn }