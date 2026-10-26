data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_kms_key" "eks" {
  description             = "EKS secret encryption for ${var.cluster_name}"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  tags                    = var.tags

  # Keep account administration explicit. The EKS cluster role is granted
  # usage of this key by a scoped IAM policy in the EKS module.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableAccountAdministration"
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

# Namespaced by cluster so dev and prod can coexist in one account/region.
resource "aws_kms_alias" "eks" {
  name          = "alias/eks/${var.cluster_name}/secrets"
  target_key_id = aws_kms_key.eks.key_id
}
