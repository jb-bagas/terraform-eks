mock_provider "aws" {}

run "vpc_plan_succeeds_with_valid_input" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    cluster_name = "test-cluster"
    environment  = "dev"
    vpc_cidr     = "10.0.0.0/16"
    azs          = ["us-east-1a", "us-east-1b"]
    tags         = { Environment = "test" }
  }
}

run "vpc_rejects_a_single_az" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    cluster_name = "test-cluster"
    environment  = "dev"
    vpc_cidr     = "10.0.0.0/16"
    azs          = ["us-east-1a"]
    tags         = { Environment = "test" }
  }

  expect_failures = [var.azs]
}

run "vpc_rejects_a_cidr_too_small_for_six_subnets" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    cluster_name = "test-cluster"
    environment  = "dev"
    vpc_cidr     = "10.0.0.0/29"
    azs          = ["us-east-1a", "us-east-1b"]
    tags         = { Environment = "test" }
  }

  expect_failures = [var.vpc_cidr]
}
