# Scenario: a developer requests a new EKS cluster

This walkthrough follows a non-production cluster request through the existing
Terraform GitHub Actions pipeline. It provisions the repository's `staging`
environment; it does not create an arbitrary cluster per ticket.

## The request

The Catalog team needs a staging cluster for pre-release API and load testing.
The platform team agrees on the following request:

| Requirement | Decision |
| --- | --- |
| Environment and cluster | `staging` / `eks-platform-staging` |
| AWS region | `us-east-1` |
| Network | New VPC, `10.2.0.0/16`, three availability zones |
| Kubernetes API | Private endpoint; Terraform runner must be VPC-connected |
| Compute | Two `t3.large` On-Demand nodes, autoscaling up to six |
| Add-ons | ALB controller, EBS CSI, Secrets Store CSI, Metrics Server, Cluster Autoscaler |
| Observability | Disabled initially to control staging costs |
| Access | Named platform administrator role and staging GitHub Actions role |
| State | Existing state bucket, separate `staging/terraform.tfstate` key |

Confirm the CIDR does not overlap with connected networks, the selected EKS
version is supported in the region, AWS quotas are sufficient, and the ongoing
cost has an owner before provisioning.

## 1. Configure staging access and state

The workflow's `staging` choice is already defined, but the GitHub environment,
OIDC role, and environment secrets must be configured before running it:

1. Create the GitHub `staging` environment. Add required reviewers if staging
   applies should be approval-gated.
2. In `bootstrap/terraform.tfvars`, include `staging` in
   `github_environments`, preserving any existing environments. Apply the
   bootstrap configuration with the normal state-bucket administrator
   credentials. The bootstrap output `github_oidc_role_arns.staging` is the
   role ARN for this environment.
3. Configure the `staging` environment with:

   | Type | Name | Value |
   | --- | --- | --- |
   | Variable | `AWS_REGION` | `us-east-1` |
   | Variable | `TF_STATE_BUCKET` | Existing Terraform state bucket |
   | Secret | `AWS_ROLE_ARN` | The staging OIDC role ARN from bootstrap |
   | Secret | `TF_VARS` | Full HCL contents from the completed staging variable template |

4. Set the repository-level `TF_RUNNER_LABEL` variable to the label of a
   self-hosted runner that can reach the VPC's private EKS endpoint. A
   GitHub-hosted runner cannot reach this private endpoint. If the runner is
   outside the VPC, provide routing and set `cluster_endpoint_access_cidrs` to
   its reachable CIDR.
5. Confirm the staging OIDC role can create the resources managed by Terraform
   and access the staging state key. The bootstrap example grants broad
   permissions; scope the role or apply an approved permissions boundary for
   a shared account.

The GitHub Actions role must also appear in `additional_admin_role_arns` in the
staging variable template. That gives the Terraform Kubernetes and Helm
providers access to install the cluster add-ons. The human platform role is
separately listed in `admin_role_arn`.

## 2. Prepare the environment configuration

The checked-in [staging variable template](../vars/staging.tfvars.example)
matches this request. Replace the example account ID and role names with real
IAM principals, and use an exact Secrets Manager ARN approved for the service.
For local Terraform use, copy the templates:

```sh
cp vars/staging.tfvars.example vars/staging.tfvars
cp backend/staging.tfbackend.example backend/staging.tfbackend
```

Set the real state bucket in `backend/staging.tfbackend`. `vars/staging.tfvars`
is git-ignored; do not commit the real configuration. The example ARNs are
placeholders, not credentials. The VPC CIDR itself is allowed to reach the
private endpoint by the EKS module; the additional endpoint CIDR list is only
needed for a runner coming from a routed network.

For GitHub Actions, put the completed variable file's HCL contents in the
`staging` environment secret `TF_VARS`; the workflow creates the backend
configuration from `TF_STATE_BUCKET`.

## 3. Generate and review the plan

In GitHub Actions, choose **Terraform → Run workflow** and dispatch:

| Input | Value |
| --- | --- |
| `environment` | `staging` |
| `action` | `plan` |

The pipeline runs its quality and secret-scanning gates, assumes the staging
OIDC role, writes the `staging/terraform.tfstate` backend configuration,
validates the HCL from `TF_VARS`, and uploads a `tfplan-staging` artifact.
Because this is a manual dispatch, the PR plan path does not choose staging;
PR and push plans default to `dev`.

Review the plan output and artifact before applying. For a new environment,
expect the VPC, EKS control plane, node group, IAM/KMS resources, and enabled
add-ons to be created. Stop if the plan includes unexpected replacements,
destruction, a public endpoint, or resources outside the request. The plan
should match the approved account, region, CIDR, node sizing, and secret scope.

## 4. Apply the reviewed plan

After review, dispatch the workflow again with:

| Input | Value |
| --- | --- |
| `environment` | `staging` |
| `action` | `apply` |
| `confirm_apply` | `apply-staging` |

The apply job consumes the most recent successful `tfplan-staging` artifact; it
does not create a fresh plan. Do not start another staging plan between
reviewing the plan and applying it. Confirm the artifact in Actions is the one
you reviewed. Any configuration change requires a new plan and review.

The workflow waits for all nodes to become Ready and checks for unhealthy
`kube-system` pods before reporting success. If apply or the smoke test fails,
inspect the Terraform job output and current state, correct the cause, then
plan again; do not treat destroy-and-recreate as the default recovery.

## 5. Verify and hand off

From an authorized workstation or the VPC-connected runner, assume the
platform administrator role and run:

```sh
aws eks update-kubeconfig --name eks-platform-staging --region us-east-1
kubectl get nodes
kubectl get pods -A
```

Confirm the expected node count, add-on health, private API access, and
environment ownership with the Catalog team. The Terraform workflow provisions
the cluster and platform add-ons; it does **not** deploy the Catalog
application. Workload deployment follows the team's approved application
delivery process.

## Scope and lifecycle

The root configuration derives one cluster name from `project_name` and
`environment`, and the workflow offers only `dev`, `staging`, and `prod`.
Requests for a second, independently managed cluster in the same environment
need a deliberate state/workflow design change; do not reuse the staging state
key for it. Cluster teardown is a separate, explicitly approved Terraform
operation and is not part of this request flow.
