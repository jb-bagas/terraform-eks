# 🚀 Production-Grade AWS EKS Platform (Terraform)

A reusable, multi-environment AWS EKS platform built using Terraform. This project follows the **"Single Codebase, Multiple Environments"** pattern to maximize maintainability and adhere to DRY (Don't Repeat Yourself) principles.

## 🏗️ Architecture

*(Add your Mermaid diagram here in Phase 4)*
> **Coming soon:** Architecture diagram showing VPC, EKS, IRSA, and Observability pipelines.

## 🛠️ Tech Stack

- **Infrastructure as Code:** Terraform (v1.10+)
- **Cloud Provider:** AWS
- **Core Services:** VPC, EKS, IAM, KMS, Secrets Manager
- **Kubernetes Add-ons:** AWS Load Balancer Controller, Secrets Store CSI Driver, ADOT Collector
- **Observability:** Amazon Managed Prometheus (AMP), Amazon Managed Grafana (AMG), AWS X-Ray, CloudWatch
- **CI/CD:** GitHub Actions with AWS OIDC Authentication

## ✨ Key Features

- **Multi-Environment Ready:** Manage `dev` and `prod` from a single root module using environment-specific `.tfvars` and `.tfbackend` files.
- **Security First:**
  - IAM Roles for Service Accounts (IRSA) implemented for all add-ons.
  - KMS encryption for EKS secrets at rest.
  - Private API endpoint access for the EKS control plane.
- **Observability Built-in:** Full metrics and tracing pipeline using AWS Distro for OpenTelemetry (ADOT), sending data to AMP and X-Ray.
- **Automated Workflows:** GitHub Actions pipeline for automated `terraform plan` on PRs and `apply` on merge (OIDC based, no long-lived keys).

## 📂 Project Structure

```text
terraform-eks/
├── main.tf                  # Root module - orchestrates everything
├── variables.tf             # All input variables
├── outputs.tf               # All outputs
├── providers.tf             # Provider + backend config
├── versions.tf              # Terraform & provider version constraints
├── makefile                 # Automation shortcuts
├── bootstrap/               # Creates the S3 bucket used for Terraform state
├── k8s-manifests/           # Kubernetes manifests
│
├── modules/                 # Reusable Terraform modules
│   ├── vpc/
│   ├── eks/
│   ├── iam/
│   ├── addons/
│   └── security/
│
├── vars/                    # Environment-specific variables
│   ├── dev.tfvars.example
│   └── prod.tfvars.example
│
└── backend/                 # Environment-specific backend configs
    ├── dev.tfbackend.example
    └── prod.tfbackend.example
```

## 🚦 Getting Started

### Prerequisites

- Terraform 1.10 or later
- AWS CLI credentials with permissions to create the infrastructure
- An AWS region and a globally unique S3 bucket name for Terraform state

### 1. Create the state bucket

The `bootstrap/` configuration uses local state to create a versioned, encrypted S3 bucket for the main Terraform configuration. Set a unique bucket name in the example variables, then apply:

```sh
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
# Edit bootstrap/terraform.tfvars and set a globally unique bucket_name.
cd bootstrap
terraform init
terraform apply
cd ..
```

Keep the bootstrap state file safe. It is stored locally in `bootstrap/terraform.tfstate`.

### 2. Configure an environment

For the environment you want to deploy, copy its example variable and backend files, then edit the copies:

```sh
cp vars/dev.tfvars.example vars/dev.tfvars
cp backend/dev.tfbackend.example backend/dev.tfbackend
```

Set the real S3 bucket name in `backend/dev.tfbackend` and review the region, network, access role, and node-group settings in `vars/dev.tfvars`. For production, use the corresponding `prod` examples. Real `.tfvars` and `.tfbackend` files are git-ignored; do not commit credentials or sensitive values.

### 3. Initialize and deploy

The Makefile defaults to `dev`. Pass `ENV=prod` to target production:

```sh
make init ENV=dev
make plan ENV=dev
make apply ENV=dev
```

Run `make destroy ENV=dev` only when you intend to tear down that environment. The Makefile expects a matching `vars/<environment>.tfvars` and `backend/<environment>.tfbackend`. Staging is not currently configured in this repository.