# Can plans run with a read-only Snowflake role?

**Short answer: not completely, so plans currently run as `TF_DEPLOYER`.** This records what was
tested and why, so the decision is not re-litigated from scratch.

## Why it matters

Plan and drift jobs run without a GitHub environment (an environment's approval would otherwise
stall every PR plan). They authenticate as `SVC_TF_PLAN_PR` / `SVC_TF_PLAN_MAIN`, which hold
`TF_DEPLOYER`. A workflow file changed in a pull request could therefore mutate Snowflake, not only
read it. The state bucket is protected (the plan role is read-only on S3), but Snowflake itself is
not. A read-only planner role would close that.

## What was tested (2026-09-29)

A `TF_PLANNER` role with only `MONITOR USAGE ON ACCOUNT` and no object privileges, running the
reads the Terraform provider performs on refresh:

| Read | Result |
|---|---|
| `SHOW DATABASES`, `SHOW WAREHOUSES`, `SHOW ROLES` | visible |
| `SHOW GRANTS TO ROLE`, `SHOW GRANTS OF ROLE`, `SHOW FUTURE GRANTS IN DATABASE`, `SHOW GRANTS ON DATABASE` | visible, no `MANAGE GRANTS` needed |
| `SHOW SCHEMAS IN DATABASE`, `SHOW PARAMETERS IN WAREHOUSE` | denied, fixable with `USAGE` / `MONITOR` grants |
| `DESCRIBE USER` | **denied** |
| `DESCRIBE NETWORK POLICY` | **denied** (reported as "does not exist or not authorized") |
| `DESCRIBE INTEGRATION` | **denied** |

Snowflake's privilege reference lists `OWNERSHIP`, `USAGE` (and for users `MONITOR`, which covers
login history only) on those three object types. None of them allows a non-owner to `DESCRIBE`.

## Why a half-working planner is worse than none

When a `SHOW` returns nothing because of missing privileges, the provider concludes the object is gone
and plans to **re-create** it. A low-privilege plan would report false drift for every user, network
policy and integration, or fail outright. A plan that is wrong is more dangerous than one that is
over-privileged, because people learn to ignore it.

## Options

| | Effect |
|---|---|
| **Keep plans on `TF_DEPLOYER` (chosen)** | Known limitation, mitigated by the other controls below |
| Move users, network policies and integrations into the manual `ACCOUNTADMIN` stack | Then a real `TF_PLANNER` works for the rest. Needs those objects destroyed and recreated in every environment, several approvals, and rebuilding the external stages that depend on the integration |

The redesign is coherent: users, network policies and trust integrations are identity and security
controls, and `stacks/governance` already exists for exactly that class of object. It was not done
because it is a migration of live objects for a risk the other controls already reduce.

## Controls that reduce the risk today

- Plans authenticate with one identity per event type (`pull_request` and `main`), so they are
  attributable and can be revoked independently.
- The plan AWS role is read-only, so a rogue job cannot rewrite state.
- Fork pull requests get no OIDC token at all, so only people with write access to this repo can
  trigger a plan.
- `CODEOWNERS` requests review on any change to `.github/`, `bootstrap/` and prod config. It is
  advisory for a sole maintainer; enforce it once there is a second one.
- Required checks and branch protection on `main`.

## If revisited

1. Do the governance migration above.
2. Create `TF_PLANNER` and grant it, from Terraform, `USAGE` on databases, `MONITOR` on warehouses and
   `REFERENCES` on future tables (metadata only, no data access).
3. Point `SVC_TF_PLAN_*` at it, and gate on "plan returns no changes" for every environment before
   removing `TF_DEPLOYER` from those users.
