# 0003 — Amazon Managed Prometheus and Grafana instead of self-hosted observability

- **Status:** Accepted
- **Date:** 2026-10-26
- **Context:** The platform needs metrics, traces, and dashboards without turning the portfolio project into a Prometheus/Grafana operations project.

## Decision

Use Amazon Managed Service for Prometheus (AMP) for metrics storage, Amazon Managed Grafana (AMG) for dashboards, AWS X-Ray for traces, and CloudWatch for control-plane and VPC flow logs. Ship telemetry through the AWS Distro for OpenTelemetry (ADOT) Collector using IRSA and SigV4.

## Consequences

### Positive

- No Prometheus/Grafana servers, storage classes, or backup jobs to operate.
- IAM-based access and AWS-managed scaling.
- Clean integration with X-Ray and CloudWatch.
- Demonstrates managed observability and OpenTelemetry.

### Negative

- AMP and AMG have usage costs that are less obvious than a small self-hosted stack.
- AMG depends on IAM Identity Center for the configured `AWS_SSO` authentication.
- Less control over Prometheus versioning, recording rules, and Grafana plugins.
- Vendor lock-in for the observability control plane.

## Alternatives considered

- **Self-hosted Prometheus + Grafana + Tempo:** more control and lower marginal cost at scale, but adds stateful workloads and operational work.
- **CloudWatch Container Insights only:** simpler, but less flexible querying and dashboard portability.
- **No managed observability:** rejected; the platform is meant to demonstrate an end-to-end telemetry path.

## Revisit when

- Telemetry volume makes AMP pricing unattractive.
- The team needs Prometheus features that AMP does not expose.
- Grafana must run with plugins or authentication that AMG cannot provide.
