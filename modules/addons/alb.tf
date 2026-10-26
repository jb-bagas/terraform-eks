resource "helm_release" "alb_controller" {
  count = var.enable_alb_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_version
  namespace  = "kube-system"

  # Zero-downtime upgrades
  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.aws_region
    vpcId       = var.vpc_id

    # HA: 2 replicas in dev, 3 in prod.
    replicaCount = local.is_prod ? 3 : 2

    podDisruptionBudget = {
      maxUnavailable = 1
    }

    resources = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }

    # IRSA
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.alb_controller_role_arn
      }
    }

    podSecurityContext = {
      fsGroup = 65534
    }
    securityContext = {
      readOnlyRootFilesystem   = true
      runAsNonRoot             = true
      allowPrivilegeEscalation = false
      capabilities = {
        drop = ["ALL"]
      }
    }

    nodeSelector = {
      "kubernetes.io/os" = "linux"
    }
    tolerations = local.system_tolerations
  })]
}
