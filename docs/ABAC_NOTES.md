# Lake Formation ABAC Notes

These notes capture the next learning track: Lake Formation attribute-based
access control with IAM principal tags and session tags.

## Current Priority

Pause the Iceberg expansion track for now.

Next learning priority:

```text
Lake Formation ABAC:
  principal attributes using IAM role tags first
  then multiple attributes
  then STS session tags
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

Learning order:

```text
1. IAM role tags
2. two role tags
3. resource LF-Tags + principal tags
4. STS session tags
5. SSO/IdP attributes later
```
