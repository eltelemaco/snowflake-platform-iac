-- =============================================================================
-- Snowflake one-time bootstrap. Run ONCE, by a human, as ACCOUNTADMIN.
--
-- Why this exists: Terraform cannot create the identity it authenticates as.
-- Everything after this script is managed as code by the pipeline.
--
-- Run in a Snowsight worksheet: select all, "Run All". Sections are idempotent.
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- 1. Deployer role: least privilege for the pipeline. NOT ACCOUNTADMIN.
--    Resource monitors are excluded on purpose: only ACCOUNTADMIN can create
--    them and that cannot be delegated. They live in stacks/governance, applied
--    manually (break-glass); the pipeline only reads them for drift detection.
CREATE ROLE IF NOT EXISTS TF_DEPLOYER
  COMMENT = 'Managed by bootstrap. Role used by the Terraform pipeline.';

GRANT CREATE ROLE          ON ACCOUNT TO ROLE TF_DEPLOYER;
GRANT CREATE DATABASE      ON ACCOUNT TO ROLE TF_DEPLOYER;
GRANT CREATE WAREHOUSE     ON ACCOUNT TO ROLE TF_DEPLOYER;
GRANT CREATE USER          ON ACCOUNT TO ROLE TF_DEPLOYER;
GRANT CREATE INTEGRATION   ON ACCOUNT TO ROLE TF_DEPLOYER;
GRANT CREATE NETWORK POLICY ON ACCOUNT TO ROLE TF_DEPLOYER;
GRANT ATTACH POLICY        ON ACCOUNT TO ROLE TF_DEPLOYER;
GRANT MANAGE GRANTS        ON ACCOUNT TO ROLE TF_DEPLOYER;
GRANT MONITOR USAGE        ON ACCOUNT TO ROLE TF_DEPLOYER;  -- read-only, for drift plans

-- Objects created by TF_DEPLOYER roll up to SYSADMIN, per Snowflake best practice.
GRANT ROLE TF_DEPLOYER TO ROLE SYSADMIN;

-- 2. Service users. One per GitHub environment, so a job running in `dev`
--    cannot authenticate as the `prod` user: the OIDC `sub` claim differs.
--    Auth is GitHub OIDC (workload identity federation). No stored secret.
--    If WIF is rejected on this trial account, see the key-pair user in section 3.
CREATE USER IF NOT EXISTS SVC_TF_DEV
  TYPE = SERVICE
  DEFAULT_ROLE = TF_DEPLOYER
  WORKLOAD_IDENTITY = (
    TYPE = OIDC
    ISSUER = 'https://token.actions.githubusercontent.com'
    SUBJECT = 'repo:eltelemaco/snowflake-platform-iac:environment:dev'
    OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
  );

CREATE USER IF NOT EXISTS SVC_TF_QA
  TYPE = SERVICE
  DEFAULT_ROLE = TF_DEPLOYER
  WORKLOAD_IDENTITY = (
    TYPE = OIDC
    ISSUER = 'https://token.actions.githubusercontent.com'
    SUBJECT = 'repo:eltelemaco/snowflake-platform-iac:environment:qa'
    OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
  );

CREATE USER IF NOT EXISTS SVC_TF_PROD
  TYPE = SERVICE
  DEFAULT_ROLE = TF_DEPLOYER
  WORKLOAD_IDENTITY = (
    TYPE = OIDC
    ISSUER = 'https://token.actions.githubusercontent.com'
    SUBJECT = 'repo:eltelemaco/snowflake-platform-iac:environment:prod'
    OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
  );

-- Plan/drift identities. Plans run WITHOUT a GitHub environment (otherwise the
-- prod approval gate would block every PR plan), so they are told apart by
-- event: pull_request vs. a run on main (push or the nightly drift schedule).
-- Known tradeoff: they share TF_DEPLOYER because `terraform plan` must refresh
-- state; a read-only TF_PLANNER role is the documented next step (README).
CREATE USER IF NOT EXISTS SVC_TF_PLAN_PR
  TYPE = SERVICE
  DEFAULT_ROLE = TF_DEPLOYER
  WORKLOAD_IDENTITY = (
    TYPE = OIDC
    ISSUER = 'https://token.actions.githubusercontent.com'
    SUBJECT = 'repo:eltelemaco/snowflake-platform-iac:pull_request'
    OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
  );

CREATE USER IF NOT EXISTS SVC_TF_PLAN_MAIN
  TYPE = SERVICE
  DEFAULT_ROLE = TF_DEPLOYER
  WORKLOAD_IDENTITY = (
    TYPE = OIDC
    ISSUER = 'https://token.actions.githubusercontent.com'
    SUBJECT = 'repo:eltelemaco/snowflake-platform-iac:ref:refs/heads/main'
    OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
  );

GRANT ROLE TF_DEPLOYER TO USER SVC_TF_PLAN_PR;
GRANT ROLE TF_DEPLOYER TO USER SVC_TF_PLAN_MAIN;
GRANT ROLE TF_DEPLOYER TO USER SVC_TF_DEV;
GRANT ROLE TF_DEPLOYER TO USER SVC_TF_QA;
GRANT ROLE TF_DEPLOYER TO USER SVC_TF_PROD;

-- 3. Key-pair user for local runs from a laptop and as the WIF fallback.
--    The matching private key lives in ~/.snowflake/tf_local_key.p8 (never in git).
CREATE USER IF NOT EXISTS SVC_TF_LOCAL
  TYPE = SERVICE
  DEFAULT_ROLE = TF_DEPLOYER
  RSA_PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArCrOUasG2afUGYo567xvzL6N4lEi491Ziuaygdab5dCcW9ue7sYQUC+sKInvergGqzh/v6X0JMg4Q+fV72oCZy9/J3OtYVUx/XKVt9WutkKkV+QTojl/b1yTWaTOJrA8mcNSLqDNz0GFLWN2Fz0jTgdgxUjIH5DSjoCNmjBSu5oGGryikDWnmn74bjqWk1iXo0P04HjA9iuyMy34z0JuhWwPrjmMyvCkZ0t+FneWSeA4QyqPOmxYshvc6Gm2c+9IlyCpnBbh8xXkeMayHFgqBDPgta5Pc7wNLCLMKHA94rqQP+1nD7H8Ncpz7+t/euQmiNN+33OndKhT00po3RY/gQIDAQAB';
GRANT ROLE TF_DEPLOYER TO USER SVC_TF_LOCAL;

-- 4. Verify. Copy these two values into the GitHub repo *variables*
--    SNOWFLAKE_ORGANIZATION_NAME and SNOWFLAKE_ACCOUNT_NAME (not in the repo).
SELECT CURRENT_ORGANIZATION_NAME() AS organization_name,
       CURRENT_ACCOUNT_NAME()      AS account_name;
SHOW USERS LIKE 'SVC_TF_%';
SHOW GRANTS TO ROLE TF_DEPLOYER;
