resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.cluster_autoscaler_version
  namespace  = "kube-system"

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  values = [yamlencode({
    cloudProvider = "aws"
    awsRegion     = var.aws_region
    replicaCount  = local.is_prod ? 2 : 1

    autoDiscovery = {
      clusterName = var.cluster_name
    }

    image = {
      repository = "registry.k8s.io/autoscaling/cluster-autoscaler"
      tag        = local.cluster_autoscaler_image_tag
    }

    extraArgs = {
      "scale-down-delay-after-add"       = "10m"
      "scale-down-unneeded-time"         = "10m"
      "scale-down-utilization-threshold" = "0.5"
      "skip-nodes-with-local-storage"    = "false"
      "skip-nodes-with-system-pods"      = "false"
      "expander"                         = "least-waste"
      "balance-similar-node-groups"      = "true"
    }

    rbac = {
      create = true
      serviceAccount = {
        create = true
        name   = "cluster-autoscaler"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.cluster_autoscaler_role_arn
        }
      }
    }

    resources = {
      requests = { cpu = "100m", memory = "300Mi" }
      limits   = { cpu = "500m", memory = "600Mi" }
    }

    podDisruptionBudget = {
      maxUnavailable = 1
    }

    tolerations = local.system_tolerations
  })]
}

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = var.metrics_server_version
  namespace  = "kube-system"

  atomic          = true
  cleanup_on_fail = true
  wait            = true

  values = [yamlencode({
    replicas = local.is_prod ? 3 : 2

    resources = {
      requests = { cpu = "100m", memory = "200Mi" }
      limits   = { cpu = "200m", memory = "300Mi" }
    }

    podDisruptionBudget = {
      enabled        = true
      maxUnavailable = 1
    }

    tolerations = local.system_tolerations
  })]
}
