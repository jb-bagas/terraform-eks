# 0002 — IRSA instead of EKS Pod Identity

- **Status:** Accepted
- **Date:** 2026-10-26
- **Context:** Pods and add-ons need AWS permissions without static credentials. The cluster targets a current EKS version and may run in accounts where EKS Pod Identity is not yet the standard.

## Decision

Use IAM Roles for Service Accounts (IRSA) for the AWS Load Balancer Controller, VPC CNI, EBS CSI, Secrets Store CSI AWS provider, Cluster Autoscaler, and ADOT Collector. Keep the OIDC provider and trust policies in Terraform.

## Consequences

### Positive

- Works across EKS versions and is widely understood.
- Trust policies are explicit and can be reviewed with the rest of the Terraform.
- No long-lived AWS keys are stored in Kubernetes or GitHub.
- The trust boundary is visible per namespace and service account.

### Negative

- Each role needs an OIDC trust policy and service-account annotation.
- The OIDC provider is a cluster-level dependency.
- Pod Identity is simpler for some teams and is the strategic AWS direction.

## Alternatives considered

- **EKS Pod Identity:** fewer moving parts and no OIDC provider, but it requires the Pod Identity Agent and a different trust model, and it is less portable to older clusters.
- **Node-instance roles:** broader blast radius and violates least privilege.
- **Static access keys in Kubernetes Secrets:** rejected.

## Revisit when

- The platform standardises on EKS Pod Identity.
- The number of IRSA roles makes trust-policy management a maintenance burden.
- A cluster must run in an environment where IRSA is unavailable.
