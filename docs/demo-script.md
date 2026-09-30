# Ten-minute walkthrough

One live change, from pull request to Snowflake, with everything that protects it visible on the way.
The live change is a new schema and table in `dev`, already prepared on branch `demo/sales-orders`
(no PR is open: you create it live, which is the first thing the audience sees). Everything here has been run for real. Linked runs are the fallback
if something misbehaves live.

Repo: https://github.com/eltelemaco/snowflake-platform-iac

## Before you start (2 minutes, not part of the ten)

1. Tabs open: the repo (**Actions** and **Pull requests**), Snowsight, the README.
2. Confirm the demo branch is current with `main` (branch protection requires it):
   `git fetch && git log --oneline origin/main..origin/demo/sales-orders` should show one commit, and
   `git log --oneline origin/demo/sales-orders..origin/main` should show none. If `main` moved, run
   `git checkout demo/sales-orders && git rebase origin/main`, then check `git rev-list --count origin/main..HEAD`
   still prints `1` before running `git push --force-with-lease`. A `0` means git dropped the commit because
   the same change is already on `main`; recreate the branch as described under "After the demo".
3. Confirm `DEV_RAW.SALES` does not exist yet: `SHOW SCHEMAS LIKE 'SALES' IN DATABASE DEV_RAW;`

## 0:00 to 1:30 . The idea and the layout

> "Everything in this Snowflake account is Terraform, and the only thing that runs Terraform is a
> pipeline that holds no credentials."

README diagram, then the tree: `modules/` (leaf objects), `stacks/platform` (the main module),
`envs/dev|qa|prod` (thin roots). Open `envs/prod/terraform.tfvars` beside `envs/dev/terraform.tfvars`:
prod keeps data 7 days, dev 1. **Promotion is a config diff, not a code copy.** No branch per
environment: the same commit runs everywhere.

## 1:30 to 4:00 . The change (live)

1. Show the diff on `demo/sales-orders`: about 20 lines in `envs/dev/terraform.tfvars`, declaring a
   `SALES` schema and an `ORDERS` table. No new Terraform code, only configuration.
2. Open the PR from the prepared branch (GitHub cannot reopen an old PR once its branch was force-pushed):
   `gh pr create --base main --head demo/sales-orders --title "dev: add SALES schema and ORDERS table" --body "Adds a schema and a table to dev only."`
3. While the checks run (about a minute) say what they are: `validate` (fmt, validate, tflint, trivy)
   and a plan for **all three environments**.
4. Read the plan comment: **dev adds 2 resources, qa and prod show No changes.** Reviewers see the
   blast radius before approving.

> "Nobody can merge until these four checks pass. The plan a person reads is the plan file that gets
> applied. If state changed in between, Terraform refuses it."

## 4:00 to 7:00 . Merge, deploy, and why there are no secrets

1. Merge the PR. Open the `deploy` run: validate, three plans, then `apply-dev`.
2. While it runs (about two minutes), open a plan job log and point at `role-to-assume: ***`.

> "There is no stored credential anywhere. GitHub mints a token per job. AWS and Snowflake each trust
> only a specific subject, so a job in dev cannot become the prod user."

3. Show the environments page: `qa` and `prod` require a reviewer, all three only accept `main`.
   Explain that qa and prod would have paused here had this change touched them.
4. Show the Snowflake side: `SHOW USERS LIKE 'SVC_TF_%';` lists the service users. Five authenticate with
   GitHub OIDC (no key, no password); `SVC_TF_LOCAL` is the one key-pair user, used from a laptop.

## 7:00 to 8:30 . Proof in Snowflake

When `apply-dev` is green, in Snowsight:

```sql
SHOW TABLES IN SCHEMA DEV_RAW.SALES;
DESC TABLE DEV_RAW.SALES.ORDERS;
SHOW GRANTS ON TABLE DEV_RAW.SALES.ORDERS;
```

The last one is the point: `DEV_RAW_RO` and `DEV_RAW_RW` already hold the right privileges, because
database-level future grants cover any new object. **No per-object grants were written.**

## 8:30 to 9:30 . One guardrail, pick one

- **Drift (60s):** `ALTER WAREHOUSE DEV_LOAD_WH SET WAREHOUSE_SIZE = SMALL;` then
  `gh workflow run drift.yml --ref main`. It opens **"Drift detected: dev"** with the diff and never
  auto-fixes. Fix it afterwards with `gh workflow run deploy.yml --ref main` (issue closes on the
  next drift run). Fallback: https://github.com/eltelemaco/snowflake-platform-iac/issues/2
- **Cost (30s):** `SHOW RESOURCE MONITORS;` shows a monthly cap per environment and on the account.
  Explain why it is a separate `ACCOUNTADMIN` stack, applied by a human: attaching a monitor needs
  account-wide `MODIFY`, which the pipeline should not hold.

## 9:30 to 10:00 . Honest limits

Say two of them from the README's **Known limitations** section, for example: the plan identities
share the deployer role (I tested a read-only planner: Snowflake cannot let a non-owner describe users,
network policies or integrations, so the fix is a redesign, documented in `docs/planner-role-findings.md`), and environments are prefixes in one
account because a trial cannot have more.

## After the demo: reset

To run it again, remove the change: revert the merge commit through a PR
(`git revert <sha>` on a branch). The pipeline then destroys the schema and table.

Then rebuild the demo branch. **Do not rebase it**: `main` now contains this change, and `git rebase` silently
drops any commit whose patch already exists upstream, leaving an empty branch. Re-apply the change by
reverting the revert instead:

```bash
git fetch origin && git checkout main && git pull
REVERT=$(git log --grep="Revert" --format=%h -1)     # the revert commit you just merged
git checkout -B demo/sales-orders origin/main
git revert --no-edit $REVERT                          # re-adds the SALES schema and ORDERS table
git push --force-with-lease origin demo/sales-orders
```

A closed PR cannot be reopened after that force-push, so create a new one for the next run.

## Extras if asked (not in the ten minutes)

- **Manual promotion:** `gh workflow run promote.yml -f environment=qa -f ref=<sha>` is plan-only by
  default. It only accepts commits on `main`. Promoting an old commit shows what a rollback would
  destroy without touching anything.
- **AWS and Snowflake together:** `LIST @DEV_RAW.LANDING.S3_LANDING;` reads `dev/` in S3 through a
  storage integration. Pointing the dev integration at `prod/` is refused.

## Questions to expect

- **Why not a Snowflake account per environment?** Trial limit. Production would use one per
  environment and the same code, since each root already has its own state and variables.
- **Why is governance a separate manual stack?** Attaching a monitor needs account-level `MODIFY`.
  Cost controls being harder to change than the platform itself is intentional.
- **Why plan without a GitHub environment?** Environment protection would pause every PR plan on the
  approval. Apply is the only step that needs a human.
- **Why no branch per environment?** The same commit is tested in dev and shipped to prod. Branches
  drift, and promotion turns into a code merge.
- **What if the state bucket is lost?** It is versioned. Restore the previous object version.
- **How would this scale to a team?** Code-owner review on workflows, a second reviewer on prod,
  self-hosted runners with fixed egress, per-environment accounts, and moving users, network policies
  and integrations into the privileged stack so a read-only planner works.
