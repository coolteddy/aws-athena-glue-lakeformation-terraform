# Lake Formation ABAC Notes

These notes capture the next learning track: Lake Formation attribute-based
access control with IAM principal tags and session tags.

## Current Priority

Pause the Iceberg expansion track for now.

Current learning priority:

```text
Lake Formation ABAC:
  principal attributes using STS session tags
  controlled session tags with IAM trust policies
  permanent IAM role tags for comparison
  Cedar-style Lake Formation ABAC conditions
```

Iceberg follow-up remains later:

```text
Glue ETL Spark bootstrap
external Iceberg writer research
```

## Mental Model

Lake Formation has two related but different tag/attribute models.

```text
LF-TBAC:
  resource-side tags
  tags are attached to databases, tables, or columns

ABAC:
  principal-side attributes
  attributes come from IAM principal tags or STS session tags
```

Example LF-TBAC:

```text
Table has:
  Classification = Shared

Grant allows:
  access to resources where Classification = Shared
```

Example ABAC:

```text
Principal has:
  department = analytics

Grant allows:
  access to principals where department = analytics
```

They can be combined later:

```text
principal attributes say who the user/session is
resource tags say what the data is
Lake Formation grants connect both sides to permissions
```

## Why Not Username

Production systems usually avoid policies like:

```text
user = Bob
```

They prefer attributes such as:

```text
department = analytics
job_role = manager
clearance = restricted
region = uk
```

Reason:

```text
people move teams
people get promoted
names and accounts change
user-specific exceptions do not scale
attributes express policy intent better
```

## Hands-On Session: 2026-09-17

### Resources Created

Terraform created ABAC learning IAM roles:

```text
lakehouse-lf-tbac-abac-alice
lakehouse-lf-tbac-abac-bob
lakehouse-lf-tbac-abac-untagged
lakehouse-lf-tbac-abac-permanent-analytics
```

Session-tag roles:

```text
alice:
  allowed session tags:
    department = analytics
    job_role = analyst

bob:
  allowed session tags:
    department = analytics
    job_role = manager

untagged:
  can assume role
  cannot pass ABAC session tags
```

Permanent-tag role:

```text
lakehouse-lf-tbac-abac-permanent-analytics:
  fixed IAM role tags:
    department = analytics
    job_role = analyst
  no sts:TagSession permission in trust policy
```

### Session Tag Guardrail

The ABAC session-tag roles use IAM trust policy conditions to control which
temporary attributes can be passed during `sts:AssumeRole`.

Alice trust-policy intent:

```text
allow sts:AssumeRole
allow sts:TagSession only when:
  aws:RequestTag/department = analytics
  aws:RequestTag/job_role = analyst
  aws:TagKeys = [department, job_role]
```

Bob trust-policy intent:

```text
allow sts:AssumeRole
allow sts:TagSession only when:
  aws:RequestTag/department = analytics
  aws:RequestTag/job_role = manager
  aws:TagKeys = [department, job_role]
```

This proved an important production pattern:

```text
Lake Formation trusts principal attributes.
IAM trust policy / SSO / IdP must control who can receive those attributes.
```

### STS Session Tag Tests

Alice with correct attributes succeeded:

```bash
AWS_PROFILE=setnay-sandbox aws sts assume-role \
  --role-arn arn:aws:iam::<account-id>:role/lakehouse-lf-tbac-abac-alice \
  --role-session-name abac-alice-test \
  --tags Key=department,Value=analytics Key=job_role,Value=analyst
```

Alice trying to pass Bob's manager attribute failed:

```bash
AWS_PROFILE=setnay-sandbox aws sts assume-role \
  --role-arn arn:aws:iam::<account-id>:role/lakehouse-lf-tbac-abac-alice \
  --role-session-name abac-alice-test \
  --tags Key=department,Value=analytics Key=job_role,Value=manager
```

Bob with manager attributes succeeded:

```bash
AWS_PROFILE=setnay-sandbox aws sts assume-role \
  --role-arn arn:aws:iam::<account-id>:role/lakehouse-lf-tbac-abac-bob \
  --role-session-name abac-bob-test \
  --tags Key=department,Value=analytics Key=job_role,Value=manager
```

### Lake Formation ABAC Tests

Manual Lake Formation ABAC grants were created in the console.

Read grant:

```text
principal attribute:
  department = analytics

permissions:
  database DESCRIBE
  table DESCRIBE, SELECT
```

Manager insert grant:

```text
principal attributes:
  department = analytics
  job_role = manager

permission:
  table INSERT
```

Observed behavior:

```text
Alice analyst:
  SELECT succeeded
  INSERT failed

Bob manager:
  eligible for INSERT because job_role=manager

Permanent analytics analyst role:
  SELECT succeeded
  INSERT failed
```

The permanent-tag role test proved that Lake Formation ABAC can evaluate fixed
IAM role tags as principal attributes, not only STS session tags.

### Permanent IAM Role Tag Test

The permanent role was assumed without passing `--tags`:

```bash
AWS_PROFILE=setnay-sandbox aws sts assume-role \
  --role-arn arn:aws:iam::<account-id>:role/lakehouse-lf-tbac-abac-permanent-analytics \
  --role-session-name abac-permanent-analytics-test
```

The role had fixed IAM tags:

```text
department = analytics
job_role = analyst
```

Results:

```text
SELECT from customers_iceberg_tf:
  SUCCEEDED

INSERT into customers_iceberg_tf:
  FAILED with Lake Formation AccessDenied
```

Lesson:

```text
Permanent IAM role tags are stable attributes on the role.
STS session tags are temporary attributes on the assumed-role session.
Lake Formation can evaluate both as principal attributes.
```

### Terraform Provider Note

We tried to model Lake Formation ABAC grants with:

```hcl
condition {
  expression = "context.iam.principalTags..."
}
```

The AWS provider rejected this:

```text
Blocks of type "condition" are not expected here.
```

Decision for now:

```text
Keep Lake Formation ABAC grants manual in the console while learning Cedar.
Keep Terraform for IAM roles, IAM trust policies, and normal LF grants.
```

## Cedar Expressions To Study Next

Read access condition:

```cedar
context.iam.principalTags.hasTag("department") &&
context.iam.principalTags.getTag("department") == "analytics"
```

Manager insert condition:

```cedar
context.iam.principalTags.hasTag("department") &&
context.iam.principalTags.getTag("department") == "analytics" &&
context.iam.principalTags.hasTag("job_role") &&
context.iam.principalTags.getTag("job_role") == "manager"
```

Interpretation:

```text
hasTag(...) checks the attribute exists.
getTag(...) reads the attribute value.
&& means all conditions must be true.
```

## Cedar Scope Decision

For the Lake Formation learning path, the Cedar knowledge needed for now is the
ABAC condition-expression subset:

```text
principal attribute exists
principal attribute equals expected value
multiple attributes are joined with AND
Lake Formation grant applies only when the condition is true
```

Full Cedar is more relevant to application authorization with AWS Verified
Permissions. That can wait until an access portal or workflow app is in scope.

Current priority after this session:

```text
1. IAM Identity Center / SSO attributes
2. Microsoft Entra ID -> IAM Identity Center attribute integration
3. Mini Posit-style Athena app that runs through Lake Formation
4. Access portal / full Cedar / Verified Permissions later
```

Important rule for external tools/apps:

```text
If the app queries through Athena with governed credentials, Lake Formation is in
the access path.

If the app reads governed S3 data directly with broad IAM permissions, it can
bypass Lake Formation.
```

## Later: LF ABAC Grants As Code

Come back to Lake Formation ABAC grants as code after building more knowledge
around IAM Identity Center, Entra, and external app/tool access patterns.

Open questions:

```text
Can Terraform model Lake Formation ABAC conditions natively yet?
If not, should we use AWS CLI grant-permissions with --condition?
How do we import or reconcile manually created ABAC grants?
How does the Cedar condition map exactly to the console-created grant?
What is the cleanest production IaC pattern?
```

Decision for now:

```text
Do not automate LF ABAC grants yet.
Keep manual console grants while learning the identity and access patterns first.
```

## Original Learning Phases

The original phase order below is kept as a learning roadmap. The actual
hands-on session started with STS session tags first, then added permanent role
tags for comparison.

## Phase 1: One Principal Attribute

Goal: prove Alice and Bob both get access because they share one attribute.

Create two test roles:

```text
lakehouse-abac-alice
lakehouse-abac-bob
```

Tag both IAM roles:

```text
department = analytics
```

Lake Formation grant:

```text
Principal type:
  Principals by attributes

Attribute:
  department = analytics

Permission:
  DESCRIBE + SELECT on one simple table
```

Expected tests:

```text
Alice can SELECT
Bob can SELECT
untagged role fails
```

Lesson:

```text
principal attribute controls who gets access
```

Use IAM role tags first because they are visible in the console and do not
require SSO or STS session tagging.

## Phase 2: Two Principal Attributes

Goal: Bob can get more access than Alice because he has a second attribute.

Role tags:

```text
Alice:
  department = analytics
  job_role = analyst

Bob:
  department = analytics
  job_role = manager
```

Possible grants:

```text
department = analytics AND job_role = analyst
  read normal table/columns

department = analytics AND job_role = manager
  read wider table/columns
```

Expected tests:

```text
Alice can read normal data
Bob can read normal + extra data
```

Lesson:

```text
one attribute is broad
two attributes narrow the match
```

## Phase 3: Add Resource Tags

Goal: combine principal attributes with resource tags.

Resource LF-Tags:

```text
Classification = Shared
Classification = Restricted
```

Principal attributes:

```text
Alice:
  department = analytics
  clearance = shared

Bob:
  department = analytics
  clearance = restricted
```

Expected tests:

```text
Alice can read Shared
Bob can read Shared + Restricted
```

Lesson:

```text
principal attributes describe the user/session
resource tags describe the data
```

## Phase 4: STS Session Tags

Goal: understand temporary attributes passed at role assumption time.

Example:

```bash
aws sts assume-role \
  --role-arn <role-arn> \
  --role-session-name alice-test \
  --tags Key=department,Value=analytics Key=job_role,Value=analyst
```

This requires the role trust policy to allow:

```text
sts:TagSession
```

Session tags are closer to real workforce identity patterns, where attributes
come from SSO or an identity provider.

Lesson:

```text
IAM role tags are static
session tags are temporary per assumed-role session
```

## SSO Later

SSO/IAM Identity Center is not needed for the first ABAC tests.

Microsoft Entra ID can be explored later through IAM Identity Center. A Windows
machine is not required; the requirement is access to a Microsoft Entra tenant
with enough admin permissions to configure SAML/SCIM and attributes.

Learning order:

```text
1. IAM role tags
2. two role tags
3. resource LF-Tags + principal tags
4. STS session tags
5. SSO/IdP attributes later
```
