# Used as: terraform init -backend-config=backend.hcl -backend-config="bucket=$TF_STATE_BUCKET"
key          = "envs/dev/terraform.tfstate"
region       = "us-east-1"
use_lockfile = true # S3-native locking, no DynamoDB table
encrypt      = true
