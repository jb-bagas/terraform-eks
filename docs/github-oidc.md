# GitHub Actions OIDC Setup

The workflow at [`.github/workflows/terraform.yml`](../.github/workflows/terraform.yml) authenticates to AWS with GitHub's OIDC provider. No long-lived AWS access keys are stored in GitHub.

## Option A — Terraform-managed OIDC (recommended)

The `bootstrap/` configuration can create the OIDC provider and one role per GitHub environment.

Add the repository and environments to `bootstrap/terraform.tfvars`:

```hcl
github_repository   = "jb-bagas/terraform-eks"
github_environments = ["dev", "prod"]
```

Then apply:

```sh
make bootstrap
```

Read the generated role ARNs:

```sh
terraform -chdir=bootstrap output -json github_oidc_role_arns
```

The trust policies pin both the repository and the environment:

```text
repo:jb-bagas/terraform-eks:environment:dev
repo:jb-bagas/terraform-eks:environment:prod
```

The bootstrap roles currently attach `PowerUserAccess` and `IAMFullAccess`, which is broad but sufficient for Terraform to create VPC, EKS, IAM, KMS, and observability resources. Replace those attachments with a scoped custom policy or a permissions boundary before using the role in a shared production account.

If you use a fork, change `github_repository` to the fork and re-apply. The GitHub environment must exist in that repository.

Add the role ARN to `additional_admin_role_arns` in the environment's `TF_VARS` too:

```hcl
additional_admin_role_arns = [
  "arn:aws:iam::<ACCOUNT_ID>:role/github-actions-eks-platform-dev",
]
```

Without this, Terraform can assume the AWS role but cannot authenticate to the EKS Kubernetes API to refresh Helm and Kubernetes resources.

## Configure GitHub environments

Add the following to each GitHub environment:

| Type | Name | Value |
| --- | --- | --- |
| Variable | `AWS_REGION` | optional; defaults to `us-east-1` in the workflow |
| Variable | `TF_STATE_BUCKET` | required; bootstrap state bucket name |
| Secret | `AWS_ROLE_ARN` | environment-specific OIDC role ARN |
| Secret | `TF_VARS` | full contents of `vars/<environment>.tfvars` |
| Secret | `GITLEAKS_LICENSE` | optional; required for organization-owned repositories |

Create the production environment if it does not exist:

```sh
gh api --method PUT repos/jb-bagas/terraform-eks/environments/prod
```

Example setup using the GitHub CLI (requires admin access):

```sh
REPO="jb-bagas/terraform-eks"
DEV_ROLE="$(terraform -chdir=bootstrap output -json github_oidc_role_arns | jq -r '.dev')"

gh variable set AWS_REGION --env dev --body "us-east-1" -R "$REPO"
gh variable set TF_STATE_BUCKET --env dev --body "jb-bagas-eks-platform-tfstate-dev" -R "$REPO"
gh secret set AWS_ROLE_ARN --env dev --body "$DEV_ROLE" -R "$REPO"
gh secret set TF_VARS --env dev -R "$REPO" < vars/dev.tfvars
```

The workflow validates `AWS_ROLE_ARN`, `TF_VARS`, `AWS_REGION`, and `TF_STATE_BUCKET` before attempting OIDC authentication, so missing configuration fails with a clear message rather than an empty action input.

`TF_VARS` must contain the **HCL file contents**, not the path `vars/dev.tfvars`. Set it with:

```sh
gh secret set TF_VARS --env dev -R jb-bagas/terraform-eks < vars/dev.tfvars
```

The workflow parses and formats the generated file before `terraform init`; a path or escaped string fails at that step with a specific error.

Also set a **repository-level** variable `TF_RUNNER_LABEL` to `self-hosted` if the workflow must run on a VPC-connected runner. `runs-on` is evaluated before environment variables are applied, so this cannot be an environment-only variable.

Add required reviewers to the `prod` environment so production applies need manual approval. The same workflow can be triggered manually with **Run workflow** and `environment=prod`, `action=apply`.

## Option B — Manual OIDC setup

### Create the provider once

```sh
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

If the provider already exists, skip this step.

### Create one role per environment

Because the workflow sets `environment: dev` or `environment: prod`, GitHub's `sub` claim is:

```text
repo:<org>/<repo>:environment:<environment>
```

Example trust policy for the `dev` role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:<org>/<repo>:environment:dev",
            "repo:<owner>@*/<repo>@*:environment:dev"
          ]
        }
      }
    }
  ]
}
```

GitHub now emits immutable owner/repository IDs in the OIDC subject, for example:

```text
repo:jb-bagas@339110344/terraform-eks@1408696656:environment:dev
```

The `StringLike` form with `@*/` and `@*:` accepts both the immutable form and the legacy owner/repo form. A trust policy that only uses `StringEquals` on the legacy subject will fail with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.

OIDC providers and roles are per AWS account. If a sandbox resets or you switch accounts, re-run bootstrap in the new account and replace the GitHub `AWS_ROLE_ARN` and `TF_VARS` values. A stale role ARN from the old account, or stale provider thumbprints, produces `The web identity token provided could not be validated`.

Repeat with `environment:prod` for the production role, then attach the permissions needed by Terraform. Scope IAM permissions to the account and, where possible, to resource ARNs, and add a permissions boundary if your organisation requires one.

## Private EKS endpoint and runners

Production defaults to a private EKS endpoint. GitHub-hosted runners cannot reach it. Use one of:

- A self-hosted GitHub Actions runner in the VPC (recommended), and set the repository-level `TF_RUNNER_LABEL` variable to its label.
- A VPN/Transit Gateway path from the runner; add the runner CIDR to `cluster_endpoint_access_cidrs` so the endpoint security group allows HTTPS.
- Temporarily enable the public endpoint with a tightly scoped `public_access_cidrs` list; do not leave `0.0.0.0/0` in production.

The `TF_VARS` secret should contain values appropriate for the account, for example:

```hcl
environment     = "prod"
aws_region      = "us-east-1"
cluster_version = "1.36"
admin_role_arn  = "arn:aws:iam::123456789012:role/GitHubTerraform-Prod"
additional_admin_role_arns = [
  "arn:aws:iam::123456789012:role/github-actions-eks-platform-prod",
]
vpc_cidr        = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
enable_public_endpoint = false
public_access_cidrs    = []
secrets_manager_secret_arns = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/app-*"]
cluster_endpoint_access_cidrs = ["10.200.0.0/16"]
node_groups = {
  general = {
    instance_types = ["m6i.large"]
    min_size       = 3
    max_size       = 12
    desired_size   = 3
    disk_size      = 100
    capacity_type  = "ON_DEMAND"
    labels         = { role = "general" }
    taints         = []
  }
}
```

The backend configuration is generated by the workflow from `TF_STATE_BUCKET`; it is not committed.
