# The caller identity is used as a safe fallback when no explicit cluster
# administrator principal is configured. Prefer setting admin_role_arn in
# production so that a human/CI role is granted access instead of a session.
data "aws_caller_identity" "current" {}

locals {
  caller_arn             = data.aws_caller_identity.current.arn
  caller_is_assumed_role = can(regex("^arn:aws[a-z-]*:sts::", local.caller_arn))
}

data "aws_iam_session_context" "current" {
  count = var.admin_role_arn == "" && local.caller_is_assumed_role ? 1 : 0
  arn   = local.caller_arn
}

# ─────────────────────────────────────────────
# LOCALS
# ─────────────────────────────────────────────
locals {
  cluster_name = "${var.project_name}-${var.environment}"

  # EKS access entries require an IAM role/user ARN, not an STS assumed-role
  # session ARN. `issuer_arn` resolves an assumed role back to its IAM ARN.
  admin_principal_arn = var.admin_role_arn != "" ? var.admin_role_arn : (
    local.caller_is_assumed_role ? data.aws_iam_session_context.current[0].issuer_arn : local.caller_arn
  )

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = "jb-bagas"
  }
}

# ─────────────────────────────────────────────
# 1. SECURITY MODULE (KMS)
# ─────────────────────────────────────────────
module "security" {
  source = "./modules/security"

  cluster_name            = local.cluster_name
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  tags                    = local.common_tags
}

# ─────────────────────────────────────────────
# 2. VPC MODULE
# ─────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  cluster_name = local.cluster_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = var.availability_zones

  # Cost optimization: one NAT for dev, one per AZ for prod.
  single_nat_gateway = var.environment != "prod"

  # Flow logs are useful in every environment; keep them on by default.
  enable_flow_logs = true

  tags = local.common_tags
}

# ─────────────────────────────────────────────
# 3. EKS MODULE
# ─────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = var.vpc_cidr
  subnet_ids      = module.vpc.private_subnet_ids
  kms_key_arn     = module.security.kms_key_arn

  enable_public_endpoint = var.enable_public_endpoint != null ? var.enable_public_endpoint : var.environment != "prod"
  public_access_cidrs    = var.public_access_cidrs
  endpoint_access_cidrs  = var.cluster_endpoint_access_cidrs

  admin_role_arn = local.admin_principal_arn
  common_tags    = local.common_tags
  node_groups    = var.node_groups
}

# ─────────────────────────────────────────────
# 4. IAM MODULE (IRSA roles for add-ons)
# ─────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  cluster_name                = module.eks.cluster_name
  oidc_provider_arn           = module.eks.oidc_provider_arn
  secrets_manager_secret_arns = var.secrets_manager_secret_arns
  tags                        = local.common_tags
}

# ─────────────────────────────────────────────
# 5. ADDONS MODULE (Helm charts + observability)
# ─────────────────────────────────────────────
module "addons" {
  source = "./modules/addons"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  aws_region      = var.aws_region
  tags            = local.common_tags

  enable_alb_controller     = var.enable_alb_controller
  enable_ebs_csi            = var.enable_ebs_csi
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  enable_metrics_server     = var.enable_metrics_server
  enable_secrets_csi        = var.enable_secrets_csi
  enable_observability      = var.enable_observability

  cluster_autoscaler_image_tag = var.cluster_autoscaler_image_tag

  alb_controller_role_arn     = module.iam.alb_controller_role_arn
  ebs_csi_role_arn            = module.iam.ebs_csi_role_arn
  cluster_autoscaler_role_arn = module.iam.cluster_autoscaler_role_arn
  secrets_csi_role_arn        = module.iam.secrets_csi_role_arn
  adot_collector_role_arn     = module.iam.adot_collector_role_arn

  depends_on = [module.eks, module.iam]
}
