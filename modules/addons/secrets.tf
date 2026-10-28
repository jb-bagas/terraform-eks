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
    # Rotate mounted secrets and sync them to Kubernetes Secrets.
    enableSecretRotation = true
    rotationPollInterval = "2m"

    syncSecret = {
      enabled = true
    }

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

    tokenRequests = [
      { audience = "sts.amazonaws.com" },
      { audience = "pods.eks.amazonaws.com" },
    ]
  })]
}

# IRSA service account for the AWS provider DaemonSet. Creating it separately
# means the annotation exists before the provider pods start, and avoids a
# post-install annotation race.
resource "kubernetes_service_account" "secrets_csi_provider" {
  count = var.enable_secrets_csi ? 1 : 0

  metadata {
    name      = "csi-secrets-store-provider-aws-irsa"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"    = "secrets-store-csi-driver-provider-aws"
      "app.kubernetes.io/part-of" = "secrets-store-csi-driver"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = var.secrets_csi_role_arn
    }
  }

  automount_service_account_token = true
}

# The AWS provider chart's RBAC only needs to read service accounts when an
# explicit region is configured (it is, via awsRegion below).
resource "kubernetes_cluster_role" "secrets_csi_provider" {
  count = var.enable_secrets_csi ? 1 : 0

  metadata {
    name = "secrets-store-csi-driver-provider-aws-irsa"
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "secrets_csi_provider" {
  count = var.enable_secrets_csi ? 1 : 0

  metadata {
    name = "secrets-store-csi-driver-provider-aws-irsa"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.secrets_csi_provider[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.secrets_csi_provider[0].metadata[0].name
    namespace = "kube-system"
  }
}

# AWS provider for the CSI driver. This pod is the component that calls
# Secrets Manager, so its service account receives the IRSA role.
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

  # Do not install a second copy of the CSI driver CRDs/daemonset.
  set {
    name  = "secrets-store-csi-driver.install"
    value = "false"
  }

  values = [yamlencode({
    awsRegion = var.aws_region

    # Use the Terraform-managed SA and RBAC above; do not let Helm create a
    # second service account without the IRSA annotation.
    rbac = {
      install            = false
      serviceAccountName = "csi-secrets-store-provider-aws-irsa"
    }

    tolerations = local.system_tolerations

    resources = {
      requests = { cpu = "50m", memory = "100Mi" }
      limits   = { cpu = "200m", memory = "200Mi" }
    }
  })]

  depends_on = [
    helm_release.secrets_csi,
    kubernetes_service_account.secrets_csi_provider,
    kubernetes_cluster_role.secrets_csi_provider,
    kubernetes_cluster_role_binding.secrets_csi_provider,
  ]
}
