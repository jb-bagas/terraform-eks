variable "environment" {
  description = "Environment name (for example dev or prod)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,15}$", var.environment))
    error_message = "environment must be 1-16 lowercase letters, digits, or hyphens."
  }

  validation {
    condition     = length("${var.project_name}-${var.environment}") <= 40
    error_message = "project_name + environment must be 40 characters or fewer so EKS, IAM, and node group names stay within AWS limits."
  }
}

variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name."
  }
}

variable "project_name" {
  description = "Project name for tagging and naming"
  type        = string
  default     = "eks-platform"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}$", var.project_name))
    error_message = "project_name must be 2-25 lowercase letters, digits, or hyphens."
  }
}

variable "cluster_version" {
  description = "EKS Kubernetes version. Pin this to a version supported by EKS in your region."
  type        = string
  default     = "1.36"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.cluster_version))
    error_message = "cluster_version must look like 1.36."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of at least two availability zones"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required by EKS."
  }
}

variable "admin_role_arn" {
  description = "Optional IAM role/user ARN to grant EKS cluster admin access. Strongly recommended in prod."
  type        = string
  default     = ""

  validation {
    condition     = var.admin_role_arn == "" || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(role|user)/.+$", var.admin_role_arn))
    error_message = "admin_role_arn must be an IAM role or user ARN, or an empty string."
  }

  validation {
    condition     = var.environment != "prod" || var.admin_role_arn != ""
    error_message = "admin_role_arn must be set for production so that the Terraform caller does not rely on an STS session ARN."
  }
}

variable "additional_admin_role_arns" {
  description = "Additional IAM role/user ARNs granted EKS cluster admin access, such as the GitHub Actions role"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.additional_admin_role_arns :
      can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:(role|user)/.+$", arn))
    ])
    error_message = "additional_admin_role_arns must contain valid IAM role or user ARNs."
  }

  validation {
    condition     = length(distinct(var.additional_admin_role_arns)) == length(var.additional_admin_role_arns)
    error_message = "additional_admin_role_arns must not contain duplicates."
  }
}

variable "enable_public_endpoint" {
  description = "Whether the EKS public API endpoint is enabled. Defaults to true for non-prod and false for prod. Set false when using a VPC runner / private access."
  type        = bool
  default     = null
  nullable    = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public endpoint when it is enabled. Restrict this in shared accounts."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "public_access_cidrs must contain valid IPv4 CIDR blocks."
  }

  validation {
    condition     = var.enable_public_endpoint != true || length(var.public_access_cidrs) > 0
    error_message = "public_access_cidrs must not be empty when enable_public_endpoint is true."
  }
}

variable "secrets_manager_secret_arns" {
  description = "Secrets Manager secret ARNs the CSI provider may read. Use specific ARNs in production."
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.secrets_manager_secret_arns) > 0 && alltrue([for arn in var.secrets_manager_secret_arns : arn == "*" || can(regex("^arn:aws[a-z-]*:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", arn))])
    error_message = "secrets_manager_secret_arns must contain '*' or valid Secrets Manager secret ARNs."
  }
}

variable "cluster_endpoint_access_cidrs" {
  description = "Additional CIDRs (for example a VPN or Transit Gateway range) allowed to reach the EKS API on 443."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.cluster_endpoint_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "cluster_endpoint_access_cidrs must contain valid IPv4 CIDR blocks."
  }
}

variable "cluster_autoscaler_image_tag" {
  description = "Optional Cluster Autoscaler image tag override. Defaults to v<cluster_version>.0."
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
}

variable "enable_alb_controller" {
  description = "Enable AWS Load Balancer Controller"
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
  description = "Enable AMP, AMG, and the ADOT Collector"
  type        = bool
  default     = true
}
