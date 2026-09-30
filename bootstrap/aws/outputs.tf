# Copy these into GitHub: repo variable TF_STATE_BUCKET and AWS_PLAN_ROLE_ARN,
# and an AWS_APPLY_ROLE_ARN variable on each GitHub *environment*.
output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  value = { for k, r in aws_iam_role.apply : k => r.arn }
}

output "landing_bucket" {
  value = aws_s3_bucket.landing.id
}
