output "stage_fully_qualified_name" {
  value = snowflake_stage_external_s3.landing.fully_qualified_name
}

# The two values AWS needs to tighten the role's trust policy. Sensitive so they
# never print in CI logs; read them locally with `terraform output -json`.
output "trust" {
  sensitive = true
  value = {
    iam_user_arn = snowflake_storage_integration_aws.this.describe_output[0].iam_user_arn
    external_id  = snowflake_storage_integration_aws.this.describe_output[0].external_id
  }
}
