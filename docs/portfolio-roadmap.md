# Portfolio Build Roadmap

This roadmap turns the platform into a defensible portfolio project. Work is intentionally split into phases with a **verification gate** between each phase. A later phase should not start until the previous gate passes.

## Operating rules

- One phase at a time.
- Every phase has a deliverable and an explicit verification gate.
- Live AWS changes that create cost require explicit approval.
- Claims in the README must be backed by a command, a plan, a screenshot, or a linked decision record.
- Do not describe the project as fully production-ready until the Phase 5 gaps are closed.

## Current baseline

- `dev` environment is deployed and `terraform plan` reports **No changes**.
- EBS CSI `csi-attacher` crash-loop was fixed by upgrading the chart from `2.35.0` to `2.62.0` and verified with a PVC mount/write test.
- Terraform formatting and validation pass for the root and bootstrap configurations.
- The repository still contains uncommitted work from the hardening pass.

## Phase summary

| Phase | Deliverable | Verification gate | Status |
| --- | --- | --- | --- |
| 0 | Baseline and publication safety | No tracked secrets; clean fmt/validate/plan; commit strategy agreed | In progress — commit strategy pending |
| 1 | Portfolio narrative and ADRs | README, decision records, evidence checklist, limitations and cost sections reviewed | Ready for review |
| 2 | Reproducible smoke tests | Script runs against `dev`, verifies PVC I/O, cleans up, leaves no resources | Pending |
| 3 | Static analysis and CI gates | `tflint`, `checkov`/`trivy`, `gitleaks`, and at least one `terraform test` pass in CI | Pending |
| 4 | Evidence capture | CI run, cluster, ingress, and observability screenshots captured and linked | Pending |
| 5 | Production-readiness backlog | Multi-account, DR, GitOps, policy, cost, and SLO gaps documented as a future roadmap | Backlog |

## Phase 0 — Baseline and publication safety

### Deliverables

- Review `git status --ignored` for state files, real `.tfvars`, backend files, and local Helm caches.
- Confirm no account IDs, ARNs, access keys, passwords, or state contents are tracked.
- Decide the commit strategy: one reviewed baseline commit or a small series of commits.
- Commit the bootstrap lock file if it is kept.

### Gate

```sh
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=vars/dev.tfvars
git grep -nE 'AKIA|aws_secret_access_key|BEGIN (RSA|OPENSSH) PRIVATE KEY'
```

Expected: formatting passes, validation passes, plan reports no changes, and the secret scan has no findings.

## Phase 1 — Portfolio narrative and ADRs

### Deliverables

- Rewrite the README opening to describe the project honestly as a production-pattern reference implementation.
- Add “What this demonstrates”, “Portfolio evidence”, “Known limitations”, “Cost profile”, and an EBS incident case study.
- Add decision records for the most important tradeoffs:
  - Custom Terraform modules vs. community modules
  - IRSA vs. EKS Pod Identity
  - AMP/AMG vs. self-hosted observability
  - Terraform-managed Helm vs. GitOps
- Add this roadmap and link it from the README.

### Gate evidence (2026-10-26)

- Four ADRs added under `docs/decisions/`.
- README now has status, “What this demonstrates”, evidence checklist, incident case study, limitations, cost, and roadmap sections.
- Relative-link check passed.
- Secret scan found only the literal scan command in this roadmap, not a credential.
- `terraform fmt -check`, `terraform validate`, and `terraform plan` remain clean.
- Phase 2 has **not** started; it waits for review of this phase.

### Gate

- Every README claim about security, observability, or delivery has a corresponding implementation or documented limitation.
- All relative links resolve.
- No screenshot placeholders are presented as completed evidence.
- A reviewer can understand the architecture, tradeoffs, and known gaps in under ten minutes.

## Phase 2 — Reproducible smoke tests

### Deliverables

- `scripts/smoke-test-ebs.sh` with `set -euo pipefail`, a cleanup trap, a unique namespace, and explicit pass/fail output.
- A `make smoke-test-ebs` target.
- Optional: `scripts/check-no-secrets.sh` for local publication checks.

### Gate

```sh
make smoke-test-ebs
kubectl get ns | grep ebs-smoke || true
kubectl get pvc -A | grep ebs-smoke || true
```

Expected: PVC binds, the pod writes and reads data, and cleanup removes the namespace, PVC, and volume.

## Phase 3 — Static analysis and CI gates

### Deliverables

- `.tflint.hcl` and a `tflint --recursive` step.
- `checkov` or `trivy config` for Terraform/IaC scanning.
- `gitleaks` for secret scanning.
- At least one `terraform test` suite covering module validation or critical plans.
- CI jobs that fail fast and upload plan output.

### Baseline findings (2026-10-26)

TFLint 0.60.0 with the bundled Terraform ruleset reports 13 warnings, mostly missing `required_version`/`required_providers` blocks in the local modules. These should be fixed in Phase 3 rather than suppressed. This is the kind of finding the phase gate exists to catch.

### Gate

- All gates pass on the current baseline, with known exceptions documented and suppressed narrowly.
- A pull request cannot merge when `fmt`, `validate`, `tflint`, secret scanning, or plan fails.
- At least one negative test proves a bad input is rejected.

## Phase 4 — Evidence capture

### Deliverables

- GitHub Actions plan/apply run link or screenshot.
- `kubectl get nodes`, `kubectl get pods -A`, and a healthy EBS/CSI screenshot.
- ALB-hosted demo application screenshot.
- AMP metric query, X-Ray trace, or Grafana dashboard screenshot.
- Before/after evidence for the EBS attacher incident.
- Optional short demo video or GIF.

### Gate

- Evidence is reproducible from documented commands.
- Screenshots do not expose account IDs, secrets, or personal data.
- The observability path has actually run, not just planned.

## Phase 5 — Production-readiness backlog

These are intentionally **not** required for the portfolio MVP, but should be documented before claiming production readiness:

- Multi-account `dev`/`prod` separation and AWS Organizations guardrails.
- Backup/restore and disaster recovery for state, EKS configuration, and persistent data.
- GitOps promotion with Argo CD or Flux instead of direct Helm apply.
- Policy-as-code, admission control, and image scanning.
- Cost budgets, alerts, and Infracost on pull requests.
- SLOs, alert routes, and incident runbooks.
- Drift detection and scheduled plans.
- EKS upgrade and add-on upgrade runbooks.

## Next action

Complete the Phase 1 gate, review the narrative and ADRs, then approve Phase 2 (smoke tests) separately.
