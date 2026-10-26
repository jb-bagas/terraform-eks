locals {
  # Use environment-aware replica counts
  is_prod = var.environment == "prod" ? true : false

  # Common tolerations for scheduling on system nodes (if you taint them)
  system_tolerations = [{
    key      = "CriticalAddonsOnly"
    operator = "Exists"
    effect   = "NoSchedule"
  }]
}