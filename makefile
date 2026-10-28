SHELL := /bin/bash

# Default environment to dev if not specified.
ENV ?= dev
TFVARS := vars/$(ENV).tfvars
BACKEND := backend/$(ENV).tfbackend

.PHONY: check-env init plan apply destroy fmt fmt-check validate lint test secrets-check scan kubeconfig clean smoke-test-ebs bootstrap bootstrap-destroy help

## Verify that the environment-specific files exist.
check-env:
	@test -f "$(TFVARS)" || (echo "Missing $(TFVARS). Copy vars/$(ENV).tfvars.example and edit it."; exit 1)
	@test -f "$(BACKEND)" || (echo "Missing $(BACKEND). Copy backend/$(ENV).tfbackend.example and edit it."; exit 1)

## Initialize the backend and download providers for a specific environment.
init: check-env
	terraform init -backend-config="$(BACKEND)" -reconfigure -input=false

## Generate and show an execution plan.
plan: check-env
	terraform plan -input=false -var-file="$(TFVARS)"

## Apply the changes to build the infrastructure.
apply: check-env
	terraform apply -input=false -var-file="$(TFVARS)"

## Destroy the infrastructure for the specified environment.
destroy: check-env
	terraform destroy -input=false -var-file="$(TFVARS)"

## Format all Terraform files.
fmt:
	terraform fmt -recursive

## Fail if any Terraform file is not formatted.
fmt-check:
	terraform fmt -check -recursive

## Validate the Terraform syntax (requires init).
validate:
	terraform validate

## Run TFLint across the root and local modules.
lint:
	tflint --recursive --config="$$(pwd)/.tflint.hcl"

## Run the Terraform test suite (mocked providers, no AWS resources).
test:
	terraform test -no-color

## Run Gitleaks if available, otherwise a local secret-scan fallback.
secrets-check:
	./scripts/check-no-secrets.sh

## Run the Trivy IaC scan (requires trivy on PATH).
scan:
	trivy config --severity CRITICAL,HIGH --ignorefile .trivyignore --exit-code 1 --format table .

## Configure kubectl for the current environment.
kubeconfig:
	aws eks update-kubeconfig \
		--name "$$(terraform output -raw cluster_name)" \
		--region "$$(terraform output -raw aws_region)"

## Remove local plan artifacts.
clean:
	rm -f "$(ENV).tfplan" tfplan plan.txt

## Run a disposable EBS CSI volume smoke test against the current cluster.
smoke-test-ebs:
	./scripts/smoke-test-ebs.sh

## Initialize and apply the bootstrap module (creates the S3 state bucket).
bootstrap:
	@test -f bootstrap/terraform.tfvars || (echo "Missing bootstrap/terraform.tfvars. Copy bootstrap/terraform.tfvars.example and edit it."; exit 1)
	cd bootstrap && terraform init && terraform apply

## Destroy the bootstrap resources (WARNING: deletes the state bucket).
bootstrap-destroy:
	@echo "WARNING: this deletes the Terraform state bucket."
	cd bootstrap && terraform destroy

## Show this help message.
help:
	@awk 'BEGIN { FS = ":" } /^## / { desc = substr($$0, 4); next } /^[a-zA-Z0-9_-]+:/ { if (desc != "") { printf "\033[36m%-20s\033[0m %s\n", $$1, desc; desc = "" } }' $(MAKEFILE_LIST) | sort
