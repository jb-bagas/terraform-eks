output "amp_workspace_arn" {
  value       = try(aws_prometheus_workspace.this[0].arn, null)
  description = "Amazon Managed Prometheus workspace ARN"
}

output "amp_workspace_endpoint" {
  value       = try(aws_prometheus_workspace.this[0].prometheus_endpoint, null)
  description = "Amazon Managed Prometheus workspace endpoint"
}

output "amg_workspace_url" {
  value       = try(aws_grafana_workspace.this[0].endpoint, null)
  description = "Amazon Managed Grafana workspace endpoint"
}

output "amg_workspace_id" {
  value       = try(aws_grafana_workspace.this[0].id, null)
  description = "Amazon Managed Grafana workspace ID"
}
