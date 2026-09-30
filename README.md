# Snowflake Platform as Code

Terraform and GitHub Actions that build and run a Snowflake platform across `dev`, `qa` and `prod`,
with **no stored credentials**, approval-gated `qa` and `prod` deploys, scheduled drift detection (every 2 hours) and
cost guardrails. Built as a working demo of how I would run a data platform, not a toy: every
claim below was executed against a real Snowflake account and is visible in this repo's Actions
history and pull requests.

- **Snowflake:** Enterprise trial on AWS `us-east-1`. **AWS:** non-prod account for state and OIDC.
- **Terraform** 1.15, provider `snowflakedb/snowflake` pinned to `2.21.0`.

## Status

Deployed and verified against a live Snowflake account (last full check: 2026-09-29). Every
environment's plan is empty, meaning the code matches reality.

| | `dev` | `qa` | `prod` |
|---|---|---|---|
| Databases | `RAW`, `ANALYTICS`, `SANDBOX` | `RAW`, `ANALYTICS` | `RAW`, `ANALYTICS` |
| Warehouses | 2 x X-Small, monitored | 2 x X-Small, monitored | 2 x X-Small, monitored |
| S3 landing stage | yes | yes | yes |
| Deploy gate | none | reviewer | reviewer |
| Time Travel | 1 day | 1 day | 7 days |

Deployed by the pipeline through GitHub OIDC: everything except the one-time bootstrap and the
governance stack, which are human-run by design (see below).

## What it does

| Capability | How | Where to look |
|---|---|---|
| Infrastructure as code for warehouses, roles, grants, cost limits, network policy | Terraform modules composed per environment | `modules/`, `stacks/platform` |
| Least-privilege RBAC | Access roles hold privileges, functional roles inherit them, users only get functional roles | `modules/rbac` |
| Keyless CI/CD | GitHub OIDC to AWS and to Snowflake (workload identity federation) | `.github/actions/tf-init`, `bootstrap/` |
| Promotion with approvals | PR plans for all envs, merge deploys `dev`, then `qa` and `prod` each wait for a human | `.github/workflows/deploy.yml` |
| Manual promotion | Deploy one commit to one environment (pin `qa`, hotfix `prod`), plan-only by default | `.github/workflows/promote.yml` |
| Drift detection | Plan per env every 2 hours, opens or closes a GitHub issue, never auto-fixes, skips while a deploy is running | `.github/workflows/drift.yml` |
| Cost governance | Monthly resource monitors, small warehouses, statement timeouts | `stacks/governance`, `modules/warehouse` |
| Validation | `fmt`, `validate`, `tflint`, `trivy` as required checks | `.github/workflows/terraform-validate.yml` |
| AWS to Snowflake data access | S3 landing bucket, storage integration and external stage per environment, read-only, prefix-isolated | `modules/s3_integration`, `bootstrap/aws/landing.tf` |

## Architecture

```mermaid
flowchart LR
  dev([Engineer]) -- pull request --> gh[GitHub]
  gh --> val["validate<br/>fmt, validate, tflint, trivy"]
  gh --> plan["plan dev / qa / prod<br/>posted as PR comment"]
  plan -- merge to main --> dep[deploy]
  dep --> ad["apply dev"]
  ad --> gq{{"qa approval"}} --> aq[apply qa]
  aq --> gate{{"prod approval<br/>required reviewer"}}
  gate --> ap[apply prod]

  subgraph identity["Keyless identity: OIDC tokens, nothing stored"]
    aws[("AWS<br/>S3 state, one key per env<br/>scoped IAM roles")]
    sf[("Snowflake<br/>service users bound to<br/>OIDC subject")]
  end

  plan -.-> aws
  plan -.-> sf
  ad -.-> aws
  ad -.-> sf
  ap -.-> aws
  ap -.-> sf

  cron([every 2 hours]) --> drift[drift plan x3]
  drift -.-> aws
  drift -.-> sf
  drift -- differs --> issue[GitHub issue]
```

## Design decisions and the tradeoffs I accepted

**Authentication: no secrets anywhere.** GitHub issues a short-lived OIDC token per job. AWS
accepts it through an IAM role whose trust policy pins the exact subject. Snowflake accepts it
through `WORKLOAD_IDENTITY` on a service user. There is no key, password or PAT in GitHub.
Account identifiers live in GitHub *secrets*, not variables, because this repo is public and
public Actions logs print variables but mask secrets.

**One Snowflake identity per GitHub context.** The OIDC `sub` claim differs for `pull_request`,
`main`, and each environment, so a job in `dev` cannot authenticate as the `prod` user.

| Snowflake user | OIDC subject (suffix) | Used for |
|---|---|---|
| `SVC_TF_PLAN_PR` | `pull_request` | PR plans |
| `SVC_TF_PLAN_MAIN` | `ref:refs/heads/main` | post-merge plans, drift |
| `SVC_TF_DEV` / `QA` / `PROD` | `environment:<env>` | applies, gated by the GitHub environment |
| `SVC_TF_LOCAL` | key pair, no OIDC | laptop runs and break-glass, private key never leaves the machine |

Plans run **without** a GitHub environment on purpose. Environment protection rules gate every
job that references the environment, so planning `prod` in a PR would otherwise stall on the
approval. Apply is the only thing that needs a human.

**GitHub's immutable subject claim.** New repos issue subjects like
`repo:<owner>@<owner-id>/<repo>@<repo-id>:...`, which survive renames and cannot be inherited by
a recreated repo of the same name. My first trust policies used the old name-only form and AWS
rejected the token. Check yours with `gh api repos/<repo>/actions/oidc/customization/sub`.

**Tables are a preview resource.** `snowflake_table` is marked preview in provider 2.x and must be enabled
with `preview_features_enabled`. The version is pinned, so behavior cannot change under it, but in a
real platform table DDL usually belongs to a migration tool (schemachange, dbt) and Terraform owns
everything up to the schema. Plans succeed without the flag and only an apply fails, so this can only
be caught by a real apply.

**New objects are a config change.** Schemas and tables are declared in an environment's
`terraform.tfvars` (`schemas`, `tables`). Database-level future grants mean a new schema or table is
usable by the right roles the moment it exists, with no per-object grants to write.

**One trunk, not a branch per environment.** The same commit is deployed to every environment and only
`envs/<env>/terraform.tfvars` differs, so what was tested in `dev` is byte-for-byte what reaches `prod`.
Branch-per-environment drifts (hotfixes that never merge back) and turns promotion into a code merge.
The automatic path always walks `dev` then `qa` then `prod`. For what it cannot express, `promote.yml`
deploys a chosen commit to a chosen environment. It only accepts commits reachable from `main`, runs
from `main` (the OIDC identities are bound to it), and is **plan-only unless `apply` is ticked**,
because `dev` has no approval gate. Applying to `qa` or `prod` still stops at the reviewer.

```
gh workflow run promote.yml -f environment=qa -f ref=<sha-or-tag>                 # plan only
gh workflow run promote.yml -f environment=prod -f ref=<sha> -f apply=true         # plan, approval, apply
```

**Plan artifact is what gets applied.** The plan job saves the plan file, the apply job downloads
it and applies exactly that. A reviewer approving `prod` approves the plan they can read. If state
changes in between, Terraform refuses the stale plan.

**Resource monitors are deliberately outside the pipeline.** Snowflake only lets `ACCOUNTADMIN`
create a resource monitor or attach one to a warehouse, and attaching needs `MODIFY` on the whole
*account*. I chose not to hand the pipeline account-wide `MODIFY`. So `stacks/governance` is
applied by a human, the pipeline creates warehouses with `ignore_changes` on the monitor, and
CI never sees `ACCOUNTADMIN`. The cost is that budget changes are slower than everything else,
which for a spend control is the right direction.

**Environments are prefixes in one account.** Objects are named `DEV_*`, `QA_*`, `PROD_*`, each
env has its own state file and its own directory (directories, not workspaces, so the diff between
environments is readable). A real platform would use one Snowflake account per environment. I
could not on a trial, and I would not hide that.

**The main module.** `stacks/platform` composes the leaf modules. `envs/<env>` are thin roots that
hold only a backend and that environment's `terraform.tfvars`, so promotion is a config diff, not
a code copy.

**S3 access without giving the pipeline IAM.** Each environment gets a Snowflake storage integration
and an external stage (`<ENV>_RAW.LANDING.S3_LANDING`) reading only `s3://<landing bucket>/<env>/`.
The bucket and the read-only IAM roles live in `bootstrap/aws`, so the pipeline that deploys Snowflake
never holds `iam:*`. Snowflake only reveals its IAM user and external ID after the integration exists,
so the trust is a two-phase handshake: the roles start trusting the AWS account, the pipeline creates
the integrations, then the trust is tightened to Snowflake's IAM user plus that integration's external
ID. Isolation is enforced twice: by the integration's allowed locations and by the IAM policy. I
tested it: reading `dev/` works, and pointing the `dev` integration at `prod/` is refused. The
account ID and role ARN are `sensitive` Terraform values so they do not appear in public plans.

## Security posture

- No long-lived credentials in GitHub, AWS or Snowflake CI paths.
- `TF_DEPLOYER` role has nine explicit account grants. It is not `ACCOUNTADMIN`.
- Network policy exists but is attached only to human demo users. GitHub-hosted runner IPs are not
  stable, so allow-listing them on the CI users would be fragile. A self-hosted runner with fixed
  egress is the production answer.
- State bucket: versioned, encrypted, public access blocked, S3-native locking (no DynamoDB).
  Apply roles can write only their own environment's state key.
- Branch protection on `main`: PR required, four checks required, branch must be up to date, no
  force-push, no deletion.
- Public-repo hygiene: account identifiers are secrets (masked in logs) or `sensitive` Terraform values
  (hidden in plans and PR comments). The landing bucket name carries a hash, not the account ID.

## Known limitations (deliberate, and what I would do next)

1. **Plan users share `TF_DEPLOYER`.** A plan must refresh state, and Snowflake gives a non-owner no
   way to `DESCRIBE` users, network policies or integrations, so a read-only planner would report
   false drift for them. I tested this rather than assuming it; see
   [`docs/planner-role-findings.md`](docs/planner-role-findings.md). The redesign (move those objects
   into the manual `ACCOUNTADMIN` stack, then add a real `TF_PLANNER`) is documented as the next step.
   Mitigations today: read-only AWS role for plans, no OIDC token for fork PRs, `CODEOWNERS` on
   workflows, and branch protection.
2. **State bucket uses SSE-S3, not a customer-managed KMS key.** Trivy flags this (AWS-0132). It is
   suppressed with a comment in `bootstrap/aws/main.tf`. Production would use a CMK.
3. **TFLint has no Snowflake ruleset.** It catches generic Terraform issues only. `validate`,
   `trivy` and the plan are the real safety net.
4. **Actions are pinned to major versions, not commit SHAs.** Production would pin SHAs.
5. **Admin bypass is on for branch protection, and CODEOWNERS is advisory.** `CODEOWNERS` requests a
   review on workflow, bootstrap and prod changes, but a sole author cannot approve their own PR, so it
   is not enforced. With a second maintainer: require code-owner review and turn off the bypass.
6. **Drift on `snowflake_execute` resources (monitor attachment) is not detected.** The scheduled
   plan covers everything else.
7. **Single account.** See above.
8. **The S3 trust handoff is manual.** After a new environment's integration exists, its IAM user and
   external ID are fed to `bootstrap/aws` (`snowflake_storage_iam`). It is a one-time step per
   environment. The landing roles are read-only, so unloading data to S3 is not covered.

## Repository layout

```
bootstrap/          one-time setup, run by a human
  snowflake_bootstrap.sql   TF_DEPLOYER role, OIDC service users (ACCOUNTADMIN, run once)
  aws/                      OIDC provider, state bucket, S3 landing bucket, scoped IAM roles (local state)
modules/            leaf modules: database, schema, table, warehouse, rbac, network_policy, resource_monitor, s3_integration
stacks/platform/    the main module, composed per environment
stacks/governance/  ACCOUNTADMIN-only controls, applied manually
envs/{dev,qa,prod}/ thin roots: backend + terraform.tfvars
envs/governance/    root for the governance stack
.github/workflows/  reusable validate / plan / apply, plus pr, deploy, promote, drift callers
.github/CODEOWNERS  review requested on workflows, bootstrap and prod config
docs/               demo-script.md (10-minute walkthrough), planner-role-findings.md (investigation)
```

## Reproduce it

1. **Snowflake:** run `bootstrap/snowflake_bootstrap.sql` once as `ACCOUNTADMIN`. Adjust the OIDC
   subjects to your repo (`gh api repos/<repo>/actions/oidc/customization/sub`).
2. **AWS:** `cd bootstrap/aws && AWS_PROFILE=<non-prod> TF_VAR_expected_account_id=<id> terraform apply`.
   The `allowed_account_ids` guard aborts if the credentials belong to another account.
3. **GitHub:** create environments `dev`, `qa`, `prod` (required reviewer on `qa` and `prod`, deploy only from
   `main`). Set repo secrets `SNOWFLAKE_ORGANIZATION_NAME`, `SNOWFLAKE_ACCOUNT_NAME`,
   `TF_STATE_BUCKET`, `AWS_PLAN_ROLE_ARN`, `AWS_ACCOUNT_ID`, and per-environment secret `AWS_APPLY_ROLE_ARN`.
4. **S3 trust (once per environment, after its first deploy):** read each environment's
   `terraform output -json s3_trust` and pass the three values to `bootstrap/aws` as
   `snowflake_storage_iam`, then re-apply it. Never commit them.
5. **Governance (once, as `ACCOUNTADMIN`):** apply `envs/governance`, then re-apply after each
   new environment so its warehouses get their monitor.
6. **Deploy:** push to `main`. Everything after that is the pipeline.

See [`docs/demo-script.md`](docs/demo-script.md) for a ten-minute walkthrough built around a live change:
a new schema and table deployed to `dev`, `qa` and `prod` through the pipeline, pausing at the approval gates.

## How this maps to running a data platform

| Responsibility | Demonstrated by |
|---|---|
| Warehouses, roles, permissions, resource monitors, networking | `modules/*`, `stacks/*` |
| Terraform as the source of truth | every object above; nothing is clicked into existence |
| CI/CD with validation, approvals, deployment, drift | `.github/workflows/` |
| Security posture | keyless auth, least-privilege roles, scoped state access, documented gaps |
| Cost governance | monitors, X-Small warehouses, 60s auto-suspend, statement timeouts |
| Operating it | drift issues, saved-plan applies, break-glass governance stack |
| Cross-platform (AWS + Snowflake) | S3 state, OIDC roles and a storage integration on AWS, WIF on the Snowflake side |

## License

MIT, see [LICENSE](LICENSE).
