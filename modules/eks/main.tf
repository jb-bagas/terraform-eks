data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition

  # Used in IRSA trust policies. The OIDC issuer is a URL; the trust policy
  # condition key drops the scheme.
  oidc_issuer_host = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

# ─────────────────────────────────────────────
# 1. CLUSTER IAM ROLE
# ─────────────────────────────────────────────
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# EKS needs KMS permissions on the cluster role to use a customer-managed key
# for encryption_config. Without this the cluster cannot be created.
resource "aws_iam_role_policy" "cluster_kms" {
  name = "${var.cluster_name}-cluster-kms"
  role = aws_iam_role.cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "UseEksEncryptionKey"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Control-plane logs are delivered by EKS; scoped permissions avoid attaching
# the broad CloudWatchLogsFullAccess managed policy.
resource "aws_iam_role_policy" "cluster_cloudwatch" {
  name = "${var.cluster_name}-cluster-cloudwatch"
  role = aws_iam_role.cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        aws_cloudwatch_log_group.cluster.arn,
        "${aws_cloudwatch_log_group.cluster.arn}:*"
      ]
    }]
  })
}

# ─────────────────────────────────────────────
# 2. EKS CLUSTER
# ─────────────────────────────────────────────
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  # EKS installs the default self-managed add-ons at cluster creation. The
  # aws_eks_addon resources below adopt and manage them explicitly; setting
  # this to false would force replacement of an existing cluster.
  bootstrap_self_managed_addons = true

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_endpoint
    public_access_cidrs     = var.enable_public_endpoint ? var.public_access_cidrs : null
    security_group_ids      = [aws_security_group.cluster.id]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy.cluster_kms,
    aws_iam_role_policy.cluster_cloudwatch,
    aws_cloudwatch_log_group.cluster
  ]

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
  tags              = var.common_tags
}

# ─────────────────────────────────────────────
# 3. CLUSTER SECURITY GROUP
# ─────────────────────────────────────────────
# EKS creates and manages the shared cluster security group that allows
# control-plane <-> node traffic. This additional group is available for
# explicit rules; it is attached to the control plane below.
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Communication between EKS control plane and nodes"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

resource "aws_security_group_rule" "cluster_ingress_from_vpc" {
  description       = "HTTPS from the VPC to the EKS API endpoint"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = distinct(concat([var.vpc_cidr], var.endpoint_access_cidrs))
}

resource "aws_security_group_rule" "cluster_egress" {
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ─────────────────────────────────────────────
# 4. NODE IAM ROLE
# ─────────────────────────────────────────────
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# ─────────────────────────────────────────────
# 5. VPC CNI IRSA ROLE
# ─────────────────────────────────────────────
# Keep AWS CNI permissions off the node role and scope them to the aws-node
# service account instead.
data "aws_iam_policy_document" "vpc_cni_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_cni" {
  name               = "${var.cluster_name}-vpc-cni"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_assume_role.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# ─────────────────────────────────────────────
# 6. MANAGED NODE GROUPS
# ─────────────────────────────────────────────
resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  instance_types = each.value.instance_types
  disk_size      = each.value.disk_size
  ami_type       = each.value.ami_type
  capacity_type  = each.value.capacity_type

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  # Only user-supplied labels belong on Kubernetes nodes; common_tags contains
  # billing tags that are not necessarily valid or useful labels.
  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints != null ? each.value.taints : []
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  update_config {
    max_unavailable = 1
  }

  # Cluster Autoscaler is authoritative for desired capacity when enabled.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_access_entry.node_role,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr
  ]

  tags = merge(var.common_tags, {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  })
}

# ─────────────────────────────────────────────
# 7. CLUSTER ACCESS ENTRIES
# ─────────────────────────────────────────────
# Managed node groups need the node role to authenticate to the API. Keep the
# node entry alongside the optional human/CI admin entry.
resource "aws_eks_access_entry" "node_role" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.node.arn
  type          = "EC2_LINUX"
}

resource "aws_eks_access_entry" "admin" {
  count         = var.admin_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  count         = var.admin_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_role_arn
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

# ─────────────────────────────────────────────
# 8. OIDC PROVIDER (Required for IRSA)
# ─────────────────────────────────────────────
data "tls_certificate" "this" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags            = var.common_tags
}

# ─────────────────────────────────────────────
# 9. CORE EKS ADD-ONS
# ─────────────────────────────────────────────
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_iam_role_policy_attachment.vpc_cni]
  tags       = var.common_tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.common_tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]
  tags                        = var.common_tags
}
