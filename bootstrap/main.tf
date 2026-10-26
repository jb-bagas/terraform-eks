terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally no backend: this configuration creates the bucket that will
  # store remote state. Keep bootstrap/terraform.tfstate safe.
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging"
  type        = string
  default     = "eks-platform"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid 3-63 character S3 bucket name."
  }
}

variable "log_bucket_name" {
  description = "Optional separate S3 bucket for state-bucket access logs. Leave empty to disable access logging."
  type        = string
  default     = ""

  validation {
    condition     = var.log_bucket_name == "" || can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.log_bucket_name))
    error_message = "log_bucket_name must be empty or a valid 3-63 character S3 bucket name."
  }

  validation {
    condition     = var.log_bucket_name == "" || var.log_bucket_name != var.bucket_name
    error_message = "log_bucket_name must be different from bucket_name."
  }
}

# ─────────────────────────────────────────────
# S3 BUCKET FOR TERRAFORM STATE
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "tfstate" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = {
    Name      = var.bucket_name
    Project   = var.project_name
    ManagedBy = "terraform-bootstrap"
    Purpose   = "terraform-state"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Enable versioning so we can recover from accidental state corruption.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [aws_s3_bucket_ownership_controls.tfstate]
}

# Encrypt state at rest (state files contain secrets).
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block ALL public access (non-negotiable for state buckets).
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce TLS and deny unencrypted object uploads.
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.tfstate.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      }
    ]
  })
}

# ─────────────────────────────────────────────
# OPTIONAL ACCESS LOG BUCKET
# ─────────────────────────────────────────────
# Server access logging cannot target the source bucket. If configured, use a
# separate bucket with the log-delivery ACL.
resource "aws_s3_bucket" "logs" {
  count         = var.log_bucket_name != "" ? 1 : 0
  bucket        = var.log_bucket_name
  force_destroy = false

  tags = {
    Name      = var.log_bucket_name
    Project   = var.project_name
    ManagedBy = "terraform-bootstrap"
    Purpose   = "terraform-state-access-logs"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count  = var.log_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  count      = var.log_bucket_name != "" ? 1 : 0
  bucket     = aws_s3_bucket.logs[0].id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = var.log_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count  = var.log_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "tfstate" {
  count         = var.log_bucket_name != "" ? 1 : 0
  bucket        = aws_s3_bucket.tfstate.id
  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "tfstate/"

  depends_on = [aws_s3_bucket_acl.logs]
}

# Clean up old noncurrent versions and incomplete multipart uploads.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}
