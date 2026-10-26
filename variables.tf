variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging and naming"
  type        = string
  default     = "eks-platform"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "admin_role_arn" {
  description = "Optional IAM principal to grant EKS cluster admin access"
  type        = string
  default     = ""
}

# Modern, flexible node group definition
variable "node_groups" {
  description = "Map of managed node group configurations"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    capacity_type  = optional(string, "ON_DEMAND")
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
}

variable "enable_alb_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_external_secrets" {
  description = "Enable External Secrets Operator"
  type        = bool
  default     = true
}

variable "enable_ebs_csi" {
  description = "Enable the EBS CSI driver"
  type        = bool
  default     = true
}

variable "enable_secrets_csi" {
  description = "Enable the Secrets Store CSI driver"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable the Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable the Kubernetes Metrics Server"
  type        = bool
  default     = true
}

variable "enable_observability" {
  description = "Enable Prometheus/Grafana stack"
  type        = bool
  default     = true
}