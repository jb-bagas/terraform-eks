variable "cluster_name" {
  description = "Name of the EKS cluster (used to namespace the KMS alias)"
  type        = string
}

variable "deletion_window_in_days" {
  description = "KMS key deletion window. Use 7 for disposable environments and 30 for production."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "tags" {
  description = "Tags applied to security resources"
  type        = map(string)
}
