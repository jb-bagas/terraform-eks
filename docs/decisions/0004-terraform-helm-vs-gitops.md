# 0004 — Terraform-managed Helm releases instead of GitOps

- **Status:** Accepted
- **Date:** 2026-10-26
- **Context:** The platform needs repeatable add-on installation without introducing a second control plane for the portfolio MVP.

## Decision

Manage cluster add-ons with the Terraform Helm provider from the same root module as the EKS cluster. Use pinned chart versions, IRSA service accounts, and `atomic`/`wait` settings for safe upgrades.

## Consequences

### Positive

- One `terraform plan` shows infrastructure and add-on changes together.
- The bootstrap path is simple: state bucket, cluster, add-ons, observability.
- Chart versions and values are reviewable in the same pull request as the infrastructure.

### Negative

- Terraform needs network access to the Kubernetes API during apply, which complicates private-endpoint CI.
- Helm state is inside Terraform state; a failed release can leave a partial state.
- There is no continuous reconciliation or drift correction for add-ons.
- The apply role needs both AWS and Kubernetes permissions.

## Alternatives considered

- **Argo CD or Flux:** better continuous reconciliation and promotion, but adds a cluster add-on, repository layout, and bootstrap ordering that are out of scope for the MVP.
- **Manual Helm:** rejected; it breaks reproducibility and auditability.
- **EKS managed add-ons only:** insufficient for ALB, EBS CSI, Secrets Store CSI, and ADOT configuration.

## Revisit when

- The platform moves to a multi-cluster or multi-account promotion model.
- Drift correction and GitOps auditability become requirements.
- Terraform apply becomes a bottleneck for day-two operations.
