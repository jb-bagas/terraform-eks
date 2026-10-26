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

    # HA: 2 replicas + PDB
    replicaCount = local.is_prod ? 3 : 2

    podDisruptionBudget = {
      maxUnavailable = 1
    }

    # Production resource limits
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

    # Security context
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

    # Control which node groups run the controller
    nodeSelector = {
      "kubernetes.io/os" = "linux"
    }
    tolerations = local.system_tolerations

    # Enable access logging to S3 (configure bucket separately)
    # enableShield        = true
    # enableWaf           = true
    # enableWafv2         = true
  })]

  depends_on = [helm_release.ebs_csi] # Ensure CSI driver is available
}