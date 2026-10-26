resource "helm_release" "ebs_csi" {
  count = var.enable_ebs_csi ? 1 : 0

  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = var.ebs_csi_version
  namespace  = "kube-system"

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 900

  values = [yamlencode({
    controller = {
      replicaCount = local.is_prod ? 2 : 1
      resources = {
        requests = { cpu = "50m", memory = "100Mi" }
        limits   = { cpu = "200m", memory = "256Mi" }
      }
      tolerations = local.system_tolerations
      serviceAccount = {
        create = true
        name   = "ebs-csi-controller-sa"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.ebs_csi_role_arn
        }
      }
    }
    node = {
      tolerations = local.system_tolerations
      serviceAccount = {
        create = true
        name   = "ebs-csi-node-sa"
      }
    }
    # Terraform owns the default StorageClass below.
    defaultStorageClass = {
      enabled = false
    }
  })]
}

# Default gp3 StorageClass (better performance and cheaper than gp2)
resource "kubernetes_storage_class" "gp3" {
  count = var.enable_ebs_csi ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [helm_release.ebs_csi]
}
