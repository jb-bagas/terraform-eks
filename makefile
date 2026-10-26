# Default environment to dev if not specified
ENV ?= dev

.PHONY: init plan apply destroy fmt validate help

## Initialize the backend and download providers for a specific environment
init:
	terraform init -backend-config=backend/$(ENV).tfbackend -reconfigure

## Generate and show an execution plan
plan:
	terraform plan -var-file=vars/$(ENV).tfvars

## Apply the changes to build the infrastructure
apply:
	terraform apply -var-file=vars/$(ENV).tfvars

## Destroy the infrastructure for the specified environment
destroy:
	terraform destroy -var-file=vars/$(ENV).tfvars

## Format all Terraform files
fmt:
	terraform fmt -recursive

## Validate the Terraform syntax
validate:
	terraform validate

## Show this help message
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.PHONY: bootstrap
## Initialize and apply the bootstrap module (creates S3 state bucket)
bootstrap:
	cd bootstrap && terraform init && terraform apply

.PHONY: bootstrap-destroy
## Destroy the bootstrap resources (WARNING: deletes state bucket)
bootstrap-destroy:
	cd bootstrap && terraform destroy