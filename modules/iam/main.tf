# 1. ALB Controller IRSA
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name                              = "${var.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  tags = var.tags
}

# 2. Secrets Store CSI Driver AWS provider IRSA
# The AWS provider pod reads Secrets Manager; the CSI driver itself does not
# need AWS credentials. The service account name matches the AWS Helm chart.
module "secrets_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name = "${var.cluster_name}-secrets-csi"
  oidc_providers = {
    main = {
      provider_arn = var.oidc_provider_arn
      # Keep the legacy service account during the transition; new pods use
      # the Terraform-managed -irsa account.
      namespace_service_accounts = [
        "kube-system:csi-secrets-store-provider-aws",
        "kube-system:csi-secrets-store-provider-aws-irsa",
      ]
    }
  }

  role_policy_arns = {
    secrets = aws_iam_policy.secrets_csi.arn
  }
  tags = var.tags
}

resource "aws_iam_policy" "secrets_csi" {
  name        = "${var.cluster_name}-secrets-csi-policy"
  description = "Allow the Secrets Store CSI AWS provider to read Secrets Manager secrets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = var.secrets_manager_secret_arns
    }]
  })
  tags = var.tags
}

# 3. ADOT Collector IRSA (Observability)
module "adot_collector_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name = "${var.cluster_name}-adot-collector"
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["adot-collector:adot-collector"]
    }
  }

  role_policy_arns = {
    adot = aws_iam_policy.adot_collector.arn
  }
  tags = var.tags
}

# 4. EBS CSI Driver IRSA (Required for persistent volumes)
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  tags = var.tags
}

# 5. Cluster Autoscaler IRSA
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name                        = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
  tags = var.tags
}

resource "aws_iam_policy" "adot_collector" {
  name        = "${var.cluster_name}-adot-collector-policy"
  description = "Allow ADOT Collector to write to AMP and X-Ray"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RemoteWriteToAmp"
        Effect   = "Allow"
        Action   = ["aps:RemoteWrite", "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"]
        Resource = "*"
      },
      {
        Sid      = "WriteXRayTraces"
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
  tags = var.tags
}
