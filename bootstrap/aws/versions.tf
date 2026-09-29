terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Local state on purpose: this stack creates the bucket the other stacks use
  # for state, so it cannot live there. Applied once by a human. State stays
  # out of git (see .gitignore).
}
