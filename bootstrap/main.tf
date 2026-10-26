terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # IMPORTANT: No backend block!
  # This uses local state (terraform.tfstate in this folder).
  # This is intentional — the S3 bucket doesn't exist yet.
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}
variable "project_name" {
  type    = string
  default = "eks-platform"
}
variable "bucket_name" {
  type = string
} # Must be globally unique

# ─────────────────────────────────────────────
# S3 BUCKET FOR TERRAFORM STATE
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "tfstate" {
  bucket        = var.bucket_name
  force_destroy = false # Prevents accidental deletion if state files exist

  tags = {
    Name      = var.bucket_name
    Project   = var.project_name
    ManagedBy = "terraform-bootstrap"
    Purpose   = "terraform-state"
  }

  lifecycle {
    prevent_destroy = true # Extra safety — requires manual override to delete
  }
}

# Enable versioning so we can recover from accidental state corruption
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (state files contain secrets!)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block ALL public access (non-negotiable for state buckets)
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce TLS for all requests to the bucket
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

# Enable access logging to detect any suspicious activity (optional but recommended)
resource "aws_s3_bucket_logging" "tfstate" {
  bucket        = aws_s3_bucket.tfstate.id
  target_bucket = aws_s3_bucket.tfstate.id # In production, use a separate logging bucket
  target_prefix = "access-logs/"
}

# Lifecycle rule to clean up old noncurrent versions (cost optimization)
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {} # Applies to all objects

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}