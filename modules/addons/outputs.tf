output "amp_workspace_arn" { value = try(aws_prometheus_workspace.this[0].arn, null) }
output "amp_workspace_endpoint" { value = try(aws_prometheus_workspace.this[0].prometheus_endpoint, null) }
output "amg_workspace_url" { value = try(aws_grafana_workspace.this[0].endpoint, null) }
output "amg_workspace_id" { value = try(aws_grafana_workspace.this[0].id, null) }