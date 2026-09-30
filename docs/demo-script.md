# Five-minute walkthrough

Goal: show a change going from a pull request to production with approval, then show the platform
noticing an out-of-band change. Everything here has been run for real. Past runs are linked as a
fallback if the live demo misbehaves.

Repo: https://github.com/eltelemaco/snowflake-platform-iac

## Before you start (2 minutes, not part of the five)

- Snowsight open on the trial account, worksheet as `TF_DEPLOYER` or your admin user.
- `gh auth status` is green. Browser tabs open on the repo's **Actions** and **Pull requests** pages.
- Confirm a clean start: `DEV_LOAD_WH` is `X-Small` and there is no open issue labelled `drift`.

## 0:00 to 1:00 . The idea

> "Everything in this Snowflake account is created by Terraform, and the only thing that runs
> Terraform is a pipeline that holds no credentials."

Show the README diagram, then the tree: `modules/`, `stacks/platform` (the main module),
`envs/dev|qa|prod` (thin roots that differ only in `terraform.tfvars`).

Point at `envs/prod/terraform.tfvars` vs `envs/dev/terraform.tfvars`: prod retention is 7 days,
dev is 1. Promotion is a config diff.

## 1:00 to 2:30 . A change, end to end

Open the merged pull request "dev: add SANDBOX database" (#1).

1. The bot comment: a plan for **all three environments**. Dev adds 13 resources, qa and prod
   show "No changes". Reviewers see blast radius before approving.
2. The checks: `validate` (fmt, validate, tflint, trivy) and three plans. All required by branch
   protection.
3. Actions history: the deploy after merge applied **dev only**, and skipped qa and prod because
   their plans were empty.

> "The plan a person reviews is the plan file the apply uses. If state moved in between,
> Terraform refuses it."

Live variant if time allows: open a tiny PR (bump a warehouse `auto_suspend_seconds` in
`envs/dev/terraform.tfvars`) and show the checks appear.

## 2:30 to 3:30 . No secrets, and why prod needs a human

Open a job log from a plan run and point at `role-to-assume: ***` and the masked account values.

> "Nothing here is a stored credential. GitHub mints a token per job. AWS and Snowflake both trust
> only a specific subject, so a job in dev cannot become the prod user."

Show the Snowflake side: `SHOW USERS LIKE 'SVC_TF_%'` and the five `WORKLOAD_IDENTITY` users. Then
the `prod` environment settings (required reviewer, deploys only from `main`) and the earlier
`deploy` run that paused on **Review deployments**.

## 3:30 to 4:45 . Drift

1. In Snowsight: `ALTER WAREHOUSE DEV_LOAD_WH SET WAREHOUSE_SIZE = SMALL;`
2. Trigger detection now instead of waiting for the nightly cron:
   `gh workflow run drift.yml --ref main`
3. Show the run: `report` fails on purpose, and issue **"Drift detected: dev"** contains the diff
   `warehouse_size = "SMALL" -> "XSMALL"`.
4. Remediate through the pipeline, not by hand: run the `deploy` workflow. `apply-dev` puts the
   size back. Re-run drift and the issue closes itself.

> "It reports, it does not auto-fix. On prod I want a person deciding whether the console change or
> the code is wrong."

Fallback if live steps fail: drift run https://github.com/eltelemaco/snowflake-platform-iac/issues/2

## Optional, 30 seconds . Promotion without branches

> "There is no branch per environment: the same commit runs everywhere and only tfvars differ. When I
> need something the automatic path can't do, like pinning qa or a prod hotfix, I promote one commit
> to one environment by hand."

`gh workflow run promote.yml -f environment=qa -f ref=<older sha>` runs plan-only by default. Show the
summary (commit, mode) and the plan. Then point out the two guardrails: the commit must be on `main`,
and nothing applies unless `apply` is ticked. Prod still pauses for approval.

## Optional, 45 seconds . AWS and Snowflake together

In Snowsight: `LIST @DEV_RAW.LANDING.S3_LANDING;` shows `dev/samples/hello.csv`. Then, to show
isolation, try to point the dev integration at prod:
`CREATE TEMPORARY STAGE DEV_RAW.LANDING.T URL='s3://<bucket>/prod/' STORAGE_INTEGRATION=DEV_S3_INTEGRATION;`
It is refused: "Location ... is not allowed by integration DEV_S3_INTEGRATION".

> "The pipeline that deploys Snowflake has no IAM permissions. The AWS side is a separate,
> human-run stack, and the two sides meet through a trust handshake."

## 4:45 to 5:00 . What I would do next

Read the **Known limitations** section aloud, at least the first two:
plan users share the deployer role (next: read-only planner), and Snowflake resource monitors need
`ACCOUNTADMIN`, so they are a deliberate manual stack outside the pipeline.

## Questions to expect

- **Why not a Snowflake account per environment?** Trial limit. Production would use one per env
  and the same code, since each root already has its own state and variables.
- **Why is governance a separate manual stack?** Attaching a monitor needs account-level
  `MODIFY`. I would not give the pipeline that. Cost controls being harder to change than the
  platform itself is intentional.
- **Why plan without a GitHub environment?** Environment protection would pause every PR plan on
  the prod approval. Apply is the only step that needs a human.
- **What if the state bucket is lost?** It is versioned. Restore the previous object version.
- **How would this scale to a team?** CODEOWNERS on workflows, a real second reviewer on prod,
  self-hosted runners with fixed egress, per-environment accounts, and a read-only planner role.
