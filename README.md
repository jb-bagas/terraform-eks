# 🚀 Production-Grade AWS EKS Platform (Terraform)

A reusable, multi-environment AWS EKS platform built using Terraform. This project follows the **"Single Codebase, Multiple Environments"** pattern to maximize maintainability and adhere to DRY (Don't Repeat Yourself) principles.

## 🏗️ Architecture

*(Add your Mermaid diagram here in Phase 4)*
> **Coming soon:** Architecture diagram showing VPC, EKS, IRSA, and Observability pipelines.

## 🛠️ Tech Stack

- **Infrastructure as Code:** Terraform (v1.5+)
- **Cloud Provider:** AWS
- **Core Services:** VPC, EKS, IAM, KMS, Secrets Manager
- **Kubernetes Add-ons:** AWS Load Balancer Controller, Secrets Store CSI Driver, ADOT Collector
- **Observability:** Amazon Managed Prometheus (AMP), Amazon Managed Grafana (AMG), AWS X-Ray, CloudWatch
- **CI/CD:** GitHub Actions with AWS OIDC Authentication

## ✨ Key Features

- **Multi-Environment Ready:** Manage `dev`, `staging`, and `prod` from a single root module using `.tfvars` and `.tfbackend` files.
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
├── Makefile                 # Automation shortcuts
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
│   ├── staging.tfvars.example
│   └── prod.tfvars.example
│
└── backend/                 # Environment-specific backend configs
    ├── dev.tfbackend.example
    ├── staging.tfbackend.example
    └── prod.tfbackend.example