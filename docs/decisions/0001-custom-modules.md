# 0001 — Custom Terraform modules instead of community modules

- **Status:** Accepted
- **Date:** 2026-10-26
- **Context:** The platform needs a reusable `dev`/`prod` EKS stack that demonstrates infrastructure design, not just module composition.

## Decision

Implement the VPC, EKS, IAM, add-on, and security layers as local modules under `modules/`. Use the community `terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks` module only for IRSA role construction, where its trust-policy and managed-policy handling is well tested.

## Consequences

### Positive

- Every resource and security rule is visible and explainable in the repository.
- The project demonstrates Terraform module design, input validation, outputs, and lifecycle reasoning.
- The platform can evolve without waiting for an upstream module release.

### Negative

- More maintenance surface than composing `terraform-aws-modules/eks/aws`.
- The implementation may lag upstream fixes for EKS, IAM, and add-on defaults.
- Reviewers must validate more custom code.

## Alternatives considered

- **`terraform-aws-modules/eks/aws`:** faster to production and well maintained, but hides too much of the design for a portfolio project and reduces the surface for demonstrating module ownership.
- **A single flat root module:** simpler initially, but repeats networking and security logic across environments.

## Revisit when

- The team needs features that are expensive to maintain locally.
- The custom modules diverge from AWS best practice.
- Operational ownership moves to a platform team that standardises on upstream modules.
