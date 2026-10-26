# ─────────────────────────────────────────────
# Core inputs
# ─────────────────────────────────────────────
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version, used to select compatible add-on images"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags applied to AWS resources"
  type        = map(string)
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
# IRSA role ARNs
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

variable "adot_collector_image_tag" {
  description = "AWS Distro for OpenTelemetry Collector image tag (not the Helm chart version)"
  type        = string
  default     = "v0.40.0"
}

variable "ebs_csi_version" {
  description = "EBS CSI Helm chart. 2.62.0+ is required for the Kubernetes 1.36 VolumeAttributesClass API."
  type        = string
  default     = "2.62.0"
}

variable "cluster_autoscaler_version" {
  type    = string
  default = "9.46.0"
}

variable "metrics_server_version" {
  type    = string
  default = "3.12.2"
}

variable "cluster_autoscaler_image_tag" {
  description = "Override the Cluster Autoscaler image tag. Defaults to v<cluster_version>.0."
  type        = string
  default     = ""
}
