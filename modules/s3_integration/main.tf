# Snowflake side of an S3 landing zone: a storage integration (the trust anchor),
# a LANDING schema and an external stage on top. The AWS bucket and IAM role live
# in bootstrap/aws, so the pipeline never needs IAM permissions.

locals {
  location = "s3://${var.bucket}/${var.prefix}/"
}

resource "snowflake_storage_integration_aws" "this" {
  name                      = "${var.environment}_S3_INTEGRATION"
  enabled                   = true
  storage_provider          = "S3"
  storage_aws_role_arn      = var.role_arn
  storage_allowed_locations = [local.location]
  comment                   = "Read-only access to ${local.location}. Managed by Terraform."
}

resource "snowflake_schema" "landing" {
  database = var.database
  name     = "LANDING"
  comment  = "External stages for raw files. Managed by Terraform."
}

resource "snowflake_stage_external_s3" "landing" {
  database            = var.database
  schema              = snowflake_schema.landing.name
  name                = "S3_LANDING"
  url                 = local.location
  storage_integration = snowflake_storage_integration_aws.this.name
  comment             = "Raw file landing zone for ${var.environment}."

  # Enabling or disabling the directory table forces the stage to be replaced, so it is off by default and
  # switched on per environment. Lets you run SELECT * FROM DIRECTORY(@stage) to list the files in the stage.
  dynamic "directory" {
    for_each = var.directory_enabled ? [1] : []
    content {
      enable       = true
      auto_refresh = "false" # no SNS wiring: refresh by hand with ALTER STAGE ... REFRESH
    }
  }
}
