resource "helm_release" "secrets_csi" {
  count = var.enable_secrets_csi ? 1 : 0

  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = var.secrets_csi_version
  namespace  = "kube-system"

  atomic          = true
  cleanup_on_fail = true
  wait            = true

  values = [yamlencode({
    # Enable automatic secret rotation (production requirement)
    enableSecretRotation = true
    rotationPollInterval = "2m"

    # Sync secrets as Kubernetes Secrets for env var injection
    syncSecret = {
      enabled = true
    }

    # HA: Run on all nodes
    linux = {
      crds = {
        metrics = true
      }
      resources = {
        requests = { cpu = "50m", memory = "100Mi" }
        limits   = { cpu = "200m", memory = "200Mi" }
      }
      tolerations = local.system_tolerations
    }

    # Enable token requests for enhanced security
    tokenRequests = [
      { audience = "sts.amazonaws.com" }
    ]
  })]
}

# AWS Provider for the CSI Driver
resource "helm_release" "secrets_csi_aws_provider" {
  count = var.enable_secrets_csi ? 1 : 0

  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = var.secrets_csi_aws_version
  namespace  = "kube-system"

  atomic          = true
  cleanup_on_fail = true
  wait            = true

  set {
    name  = "secrets-store-csi-driver.install"
    value = "false"
  }

  values = [yamlencode({
    tolerations = local.system_tolerations
    resources = {
      requests = { cpu = "50m", memory = "100Mi" }
      limits   = { cpu = "200m", memory = "200Mi" }
    }
  })]

  depends_on = [helm_release.secrets_csi]
}