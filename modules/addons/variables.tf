# ─────────────────────────────────────────────
# Core inputs
# ─────────────────────────────────────────────
variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type = map(string)
}

# ─────────────────────────────────────────────
# Feature flags
# ─────────────────────────────────────────────
variable "enable_alb_controller" {
  type    = bool
  default = true
}

variable "enable_secrets_csi" {
  type    = bool
  default = true
}

variable "enable_ebs_csi" {
  type    = bool
  default = true
}

variable "enable_observability" {
  type    = bool
  default = true
}

variable "enable_cluster_autoscaler" {
  type    = bool
  default = true
}

variable "enable_metrics_server" {
  type    = bool
  default = true
}

# ─────────────────────────────────────────────
# IRSA Role ARNs
# ─────────────────────────────────────────────
variable "alb_controller_role_arn" {
  type = string
}

variable "secrets_csi_role_arn" {
  type = string
}

variable "adot_collector_role_arn" {
  type = string
}

variable "ebs_csi_role_arn" {
  type = string
}

variable "cluster_autoscaler_role_arn" {
  type = string
}

# ─────────────────────────────────────────────
# Pinned Helm chart versions
# ─────────────────────────────────────────────
variable "alb_controller_version" {
  type    = string
  default = "1.8.1"
}

variable "secrets_csi_version" {
  type    = string
  default = "1.5.6"
}

variable "secrets_csi_aws_version" {
  type    = string
  default = "3.1.2"
}

variable "adot_collector_version" {
  type    = string
  default = "0.108.0"
}

variable "ebs_csi_version" {
  type    = string
  default = "2.35.0"
}

variable "cluster_autoscaler_version" {
  type    = string
  default = "9.46.0"
}

variable "metrics_server_version" {
  type    = string
  default = "3.12.2"
}