locals {
  is_prod = var.environment == "prod"

  # Common toleration for the optional dedicated system node group. It does
  # not force pods onto those nodes; it only lets them schedule there.
  system_tolerations = [{
    key      = "CriticalAddonsOnly"
    operator = "Exists"
    effect   = "NoSchedule"
  }]

  # Cluster Autoscaler images are versioned with the Kubernetes minor version.
  cluster_autoscaler_image_tag = var.cluster_autoscaler_image_tag != "" ? var.cluster_autoscaler_image_tag : "v${var.cluster_version}.0"

  # AMP returns an HTTPS endpoint with a trailing slash. ADOT expects the full
  # remote-write URL; using http here silently breaks SigV4 authentication.
  amp_remote_write_endpoint = try(
    "${trimsuffix(aws_prometheus_workspace.this[0].prometheus_endpoint, "/")}/api/v1/remote_write",
    ""
  )
}
