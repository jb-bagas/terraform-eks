# Get the current AWS identity to grant it admin access to the cluster
data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
# LOCALS
# ─────────────────────────────────────────────
locals {
  cluster_name = "${var.project_name}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = "jb-bagas"
  }
}

# ─────────────────────────────────────────────
# 1. SECURITY MODULE (KMS Keys)
# ─────────────────────────────────────────────
module "security" {
  source = "./modules/security"

  tags = local.common_tags
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

  # Cost optimization: 1 NAT for dev/staging, 1 per AZ for prod
  single_nat_gateway = var.environment == "prod" ? false : true

  # Enable flow logs in prod and staging, disable in dev to save CloudWatch costs
  enable_flow_logs = var.environment != "dev"

  tags = local.common_tags
}

# ─────────────────────────────────────────────
# 3. EKS MODULE
# ─────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name           = local.cluster_name
  cluster_version        = var.cluster_version
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnet_ids # Aligned with VPC output
  kms_key_arn            = module.security.kms_key_arn
  enable_public_endpoint = var.environment == "prod" ? false : true

  # Use the configured admin principal, or fall back to the Terraform caller.
  admin_role_arn = var.admin_role_arn != "" ? var.admin_role_arn : data.aws_caller_identity.current.arn

  common_tags = local.common_tags
  node_groups = var.node_groups # Uses the robust map object we defined
}

# ─────────────────────────────────────────────
# 4. IAM MODULE (IRSA Roles)
# ─────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  tags              = local.common_tags
}

# ─────────────────────────────────────────────
# 5. ADDONS MODULE (Helm Charts)
# ─────────────────────────────────────────────
# ─────────────────────────────────────────────
# 5. ADDONS MODULE (Helm Charts)
# ─────────────────────────────────────────────
module "addons" {
  source = "./modules/addons"

  cluster_name     = local.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  aws_region       = var.aws_region
  tags             = local.common_tags

  enable_alb_controller     = var.enable_alb_controller
  enable_ebs_csi            = var.enable_ebs_csi
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  enable_metrics_server     = var.enable_metrics_server
  enable_secrets_csi        = var.enable_secrets_csi
  enable_observability      = var.enable_observability

  alb_controller_role_arn     = module.iam.alb_controller_role_arn
  ebs_csi_role_arn            = module.iam.ebs_csi_role_arn
  cluster_autoscaler_role_arn = module.iam.cluster_autoscaler_role_arn
  secrets_csi_role_arn        = module.iam.secrets_csi_role_arn
  adot_collector_role_arn     = module.iam.adot_collector_role_arn

  depends_on = [module.eks, module.iam]
}