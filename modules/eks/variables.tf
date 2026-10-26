variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = length(var.cluster_name) <= 40
    error_message = "cluster_name must be 40 characters or fewer so IAM and node group names stay within AWS limits."
  }
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.36"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.cluster_version))
    error_message = "cluster_version must look like 1.36."
  }
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR allowed to reach the private EKS endpoint on 443"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "endpoint_access_cidrs" {
  description = "Additional CIDRs allowed to reach the EKS API on 443"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.endpoint_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "endpoint_access_cidrs must contain valid IPv4 CIDR blocks."
  }
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the cluster"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires at least two subnets in different availability zones."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for secret encryption"
  type        = string
}

variable "enable_public_endpoint" {
  description = "Whether to enable public access to the cluster endpoint"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public endpoint when it is enabled"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "public_access_cidrs must contain valid IPv4 CIDR blocks."
  }

  validation {
    condition     = !var.enable_public_endpoint || length(var.public_access_cidrs) > 0
    error_message = "public_access_cidrs must not be empty when enable_public_endpoint is true."
  }
}

variable "cluster_log_retention_days" {
  description = "CloudWatch retention for EKS control-plane logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cluster_log_retention_days)
    error_message = "cluster_log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

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

  validation {
    condition = alltrue([
      for group in values(var.node_groups) :
      group.min_size >= 0 &&
      group.max_size >= group.min_size &&
      group.desired_size >= group.min_size &&
      group.desired_size <= group.max_size &&
      group.disk_size > 0
    ])
    error_message = "Each node group must satisfy min_size <= desired_size <= max_size and have a positive disk_size."
  }

  validation {
    condition     = alltrue([for key in keys(var.node_groups) : length("${var.cluster_name}-${key}") <= 63])
    error_message = "Each node group name (cluster_name-key) must be 63 characters or fewer."
  }

  validation {
    condition     = alltrue([for group in values(var.node_groups) : length(group.instance_types) > 0])
    error_message = "Each node group must define at least one instance type."
  }
}

variable "admin_role_arn" {
  description = "ARN of the IAM role/user that should have cluster admin access"
  type        = string
  default     = ""

  validation {
    condition     = var.admin_role_arn == "" || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(role|user)/.+$", var.admin_role_arn))
    error_message = "admin_role_arn must be an IAM role or user ARN, or an empty string."
  }
}
