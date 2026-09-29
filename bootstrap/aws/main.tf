provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = { project = "snowflake-platform-iac", managed_by = "terraform-bootstrap" }
  }
}

data "aws_caller_identity" "current" {}

locals {
  oidc_host  = "token.actions.githubusercontent.com"
  bucket     = "snowflake-platform-iac-tfstate-${data.aws_caller_identity.current.account_id}"
  bucket_arn = "arn:aws:s3:::${local.bucket}"

  plan_subjects = [
    "repo:${var.github_repo}:pull_request",
    "repo:${var.github_repo}:ref:refs/heads/main",
  ]
}

# --- state bucket ---------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket = local.bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Accepted exception (AWS-0132): SSE-S3 (AES256) is enough for this non-prod state
# bucket. Production would use a customer-managed KMS key plus kms:* on the roles.
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- GitHub OIDC ----------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = local.plan_subjects
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  for_each = var.environments

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${var.github_repo}:environment:${each.key}"]
    }
  }
}

# Plan: read-only on state. Plans run with -lock=false, so no writes at all.
resource "aws_iam_role" "plan" {
  name               = "gha-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

data "aws_iam_policy_document" "plan" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [local.bucket_arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${local.bucket_arn}/envs/*"]
  }
}

resource "aws_iam_role_policy" "plan" {
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# Apply: one role per environment, read/write only on that environment's state key.
resource "aws_iam_role" "apply" {
  for_each           = var.environments
  name               = "gha-terraform-apply-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.apply_trust[each.key].json
}

data "aws_iam_policy_document" "apply" {
  for_each = var.environments

  statement {
    actions   = ["s3:ListBucket"]
    resources = [local.bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["envs/${each.key}/*"]
    }
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.bucket_arn}/envs/${each.key}/*"] # includes the .tflock file
  }
}

resource "aws_iam_role_policy" "apply" {
  for_each = var.environments
  role     = aws_iam_role.apply[each.key].id
  policy   = data.aws_iam_policy_document.apply[each.key].json
}
