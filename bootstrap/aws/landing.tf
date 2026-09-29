# S3 landing zone read by Snowflake through storage integrations. AWS side only:
# the Snowflake integrations, schemas and stages are managed by the pipeline.
# Bucket name carries a short hash instead of the account ID so it can be
# committed to a public repo.

locals {
  landing_bucket = "snowflake-platform-iac-landing-${substr(sha256(data.aws_caller_identity.current.account_id), 0, 10)}"
  landing_arn    = "arn:aws:s3:::${local.landing_bucket}"
}

resource "aws_s3_bucket" "landing" {
  bucket = local.landing_bucket
}

resource "aws_s3_bucket_versioning" "landing" {
  bucket = aws_s3_bucket.landing.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Accepted exception (AWS-0132): SSE-S3 is enough for non-prod demo data.
# Production would use a customer-managed KMS key.
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "landing" {
  bucket                  = aws_s3_bucket.landing.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# One read-only role per environment, limited to that environment's prefix.
data "aws_iam_policy_document" "snowflake_trust" {
  for_each = var.environments

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        contains(keys(var.snowflake_storage_iam), each.key)
        ? var.snowflake_storage_iam[each.key].iam_user_arn
        : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    dynamic "condition" {
      for_each = contains(keys(var.snowflake_storage_iam), each.key) ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.snowflake_storage_iam[each.key].external_id]
      }
    }
  }
}

resource "aws_iam_role" "snowflake_s3" {
  for_each           = var.environments
  name               = "snowflake-s3-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.snowflake_trust[each.key].json
}

data "aws_iam_policy_document" "snowflake_s3" {
  for_each = var.environments

  statement {
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${local.landing_arn}/${each.key}/*"]
  }
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [local.landing_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${each.key}/*"]
    }
  }
}

resource "aws_iam_role_policy" "snowflake_s3" {
  for_each = var.environments
  role     = aws_iam_role.snowflake_s3[each.key].id
  policy   = data.aws_iam_policy_document.snowflake_s3[each.key].json
}
