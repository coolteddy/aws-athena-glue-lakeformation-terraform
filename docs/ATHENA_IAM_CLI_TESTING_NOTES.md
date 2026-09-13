# Athena, IAM, and Lake Formation Testing Notes

These notes capture the testing sequence from `terraform/`.

The main lesson is the split between IAM and Lake Formation:

```text
IAM controls whether the role can call AWS APIs:
  Athena, Glue, S3, KMS

Lake Formation controls whether the role can access catalog resources:
  databases, tables, columns

LF-Tags let Lake Formation grant access by matching resource tags:
  Classification = Shared
```

## Context

The learning stack has:

```text
Athena workgroup: sandbox-lakehouse-lf-tbac-team1-workgroup
Athena workgroup: sandbox-lakehouse-lf-tbac-team2-workgroup

Glue database:    lakehouse_lf_tbac_team1_sandbox
Glue database:    lakehouse_lf_tbac_team2_sandbox

S3 data bucket:   sandbox-lakehouse-lf-tbac-team1-temp
S3 data bucket:   sandbox-lakehouse-lf-tbac-team2-temp

Table:            customers
```

Two test roles were created:

```text
lakehouse-lf-tbac-team1-analyst
lakehouse-lf-tbac-reader
```

`team1-analyst` is narrow. It can query only team1.

`reader` is broad at the IAM layer. It can call Athena/Glue/S3/KMS for both
team1 and team2. This makes it useful for Lake Formation testing, because IAM
is no longer the first thing blocking access.

## Keep Admin And Test Role Terminals Separate

Use two terminal sessions.

Admin/Terraform terminal:

```bash
AWS_PROFILE=<your-profile> terraform plan
AWS_PROFILE=<your-profile> terraform apply
```

Restricted role test terminal:

```bash
aws sts get-caller-identity
aws athena start-query-execution ...
```

Do not run Terraform while the restricted role credentials are exported.
Terraform needs broad read/manage permissions to refresh state.

If needed, clear temporary credentials with:

```bash
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
```

## Confirm Current Identity

After assuming a test role, confirm the active identity:

```bash
aws sts get-caller-identity
```

Expected shape for the team1 analyst:

```json
{
  "Arn": "arn:aws:sts::<account-id>:assumed-role/lakehouse-lf-tbac-team1-analyst/team1-analyst-test"
}
```

Expected shape for the reader:

```json
{
  "Arn": "arn:aws:sts::<account-id>:assumed-role/lakehouse-lf-tbac-reader/reader-test"
}
```

Either shape confirms the shell is no longer using the SSO AdministratorAccess
role.

## Phase 1: IAM-Only Team1 Analyst Test

This proves a narrow IAM role can query only the team1 resources.

### Positive Test: Team1 Analyst Can Query Team1 Data

Start an Athena query:

```bash
aws athena start-query-execution \
  --region eu-west-2 \
  --work-group sandbox-lakehouse-lf-tbac-team1-workgroup \
  --query-execution-context Database=lakehouse_lf_tbac_team1_sandbox \
  --query-string "SELECT * FROM customers;"
```

Expected output:

```json
{
  "QueryExecutionId": "<query-execution-id>"
}
```

Check query status:

```bash
aws athena get-query-execution \
  --region eu-west-2 \
  --query-execution-id "<query-execution-id>" \
  --query 'QueryExecution.Status'
```

Expected state:

```json
{
  "State": "SUCCEEDED"
}
```

Fetch results:

```bash
aws athena get-query-results \
  --region eu-west-2 \
  --query-execution-id "<query-execution-id>" \
  --output table
```

Expected rows:

```text
customer_id  customer_name  region
1            Alice          London
2            Ben            Manchester
3            Carys          Cardiff
```

### Negative Test: Team1 Analyst Cannot Use Team2 Workgroup

Try to query team2 through the team2 workgroup:

```bash
aws athena start-query-execution \
  --region eu-west-2 \
  --work-group sandbox-lakehouse-lf-tbac-team2-workgroup \
  --query-execution-context Database=lakehouse_lf_tbac_team2_sandbox \
  --query-string "SELECT * FROM customers;"
```

Expected result:

```text
AccessDeniedException: You are not authorized to perform: athena:StartQueryExecution on the resource.
```

This proves IAM is already restricting the role before Lake Formation is added.

### Negative Test: Team1 Analyst Cannot Read Team2 Glue Database

Use the allowed team1 workgroup, but point the query at the team2 database:

```bash
aws athena start-query-execution \
  --region eu-west-2 \
  --work-group sandbox-lakehouse-lf-tbac-team1-workgroup \
  --query-execution-context Database=lakehouse_lf_tbac_team2_sandbox \
  --query-string "SELECT * FROM customers;"
```

The query may be accepted and return a `QueryExecutionId`.

Check the status:

```bash
aws athena get-query-execution \
  --region eu-west-2 \
  --query-execution-id "<query-execution-id>" \
  --query 'QueryExecution.Status'
```

Expected failure:

```text
not authorized to perform: glue:GetDatabase
```

This proves Athena query submission and query execution are different stages.
`StartQueryExecution` can succeed, then the query can fail when Athena checks
Glue permissions during execution.

## Phase 2: Reader Baseline Before Lake Formation Lockdown

Assume the broad reader role:

```bash
AWS_PROFILE=<your-profile> aws sts assume-role \
  --role-arn arn:aws:iam::<account-id>:role/lakehouse-lf-tbac-reader \
  --role-session-name reader-test
```

Export the temporary credentials in a separate terminal, then confirm:

```bash
aws sts get-caller-identity
```

Expected role:

```text
lakehouse-lf-tbac-reader
```

Run the team1 query:

```bash
aws athena start-query-execution \
  --region eu-west-2 \
  --work-group sandbox-lakehouse-lf-tbac-team1-workgroup \
  --query-execution-context Database=lakehouse_lf_tbac_team1_sandbox \
  --query-string "SELECT * FROM customers;"
```

Run the team2 query:

```bash
aws athena start-query-execution \
  --region eu-west-2 \
  --work-group sandbox-lakehouse-lf-tbac-team2-workgroup \
  --query-execution-context Database=lakehouse_lf_tbac_team2_sandbox \
  --query-string "SELECT * FROM customers;"
```

Check both query IDs with `get-query-execution`.

Expected result before Lake Formation lockdown:

```text
team1: SUCCEEDED
team2: SUCCEEDED
```

Why both work:

```text
reader IAM policy allows both teams
IAMAllowedPrincipals still has broad Lake Formation permissions
```

## Phase 3: Revoke IAMAllowedPrincipals From Team2

In the Lake Formation console:

```text
Lake Formation -> Permissions -> Data permissions
```

Filter:

```text
Principal = IAMAllowedPrincipals
Database = lakehouse_lf_tbac_team2_sandbox
```

Revoke the two team2 rows:

```text
Database: lakehouse_lf_tbac_team2_sandbox / All
Table:    lakehouse_lf_tbac_team2_sandbox.customers / All
```

Leave team1 untouched.

Run the reader query against team2 again:

```bash
aws athena start-query-execution \
  --region eu-west-2 \
  --work-group sandbox-lakehouse-lf-tbac-team2-workgroup \
  --query-execution-context Database=lakehouse_lf_tbac_team2_sandbox \
  --query-string "SELECT * FROM customers;"
```

Check the query status.

Expected result:

```text
FAILED
Insufficient Lake Formation permission(s): Required Describe on lakehouse_lf_tbac_team2_sandbox
```

This proves:

```text
IAM still allows the APIs
Lake Formation now denies the catalog resource
```

Run the reader query against team1 again.

Expected result:

```text
SUCCEEDED
```

Why team1 still works:

```text
IAMAllowedPrincipals still exists for team1 database/table
```

## Phase 4: Direct Lake Formation Grant

In the Lake Formation console:

```text
Lake Formation -> Permissions -> Data permissions -> Grant
```

Grant to:

```text
Principal: lakehouse-lf-tbac-reader
Resource:  Named Data Catalog resources
Database:  lakehouse_lf_tbac_team2_sandbox
Table:     customers
```

Permissions:

```text
Database permissions:
  Describe

Table permissions:
  Describe
  Select
```

Leave grantable permissions unchecked.

Run the team2 reader query again.

Expected result:

```text
SUCCEEDED
```

This proves direct Lake Formation permissions can allow access even after
`IAMAllowedPrincipals` has been removed.

Lake Formation may display this as:

```text
Table  / Describe
Column / Select
```

That is normal. `SELECT` is column-level in Lake Formation because it can
grant access to only some columns.

## Phase 5: Replace Direct Grant With LF-TBAC

First revoke the direct reader grants from team2:

```text
Principal: lakehouse-lf-tbac-reader
Rows:
  Table  / Describe
  Column / Select
```

Run the team2 reader query again.

Expected result:

```text
FAILED
Insufficient Lake Formation permission(s)
```

Create an LF-Tag:

```text
Key:    Classification
Value:  Shared
```

Do not grant tag-management permissions to the reader role. The reader should
consume data selected by tags, not manage the tag system.

Attach the LF-Tag to the team2 database:

```text
Database: lakehouse_lf_tbac_team2_sandbox
LF-Tag:   Classification = Shared
```

The `customers` table should inherit the tag from the database:

```text
Table:          customers
LF-Tag:         Classification = Shared
Inherited from: lakehouse_lf_tbac_team2_sandbox
```

Grant reader access by LF-Tag expression:

```text
Principal: lakehouse-lf-tbac-reader
Resource:  Resources matched by LF-Tags
Expression:
  Classification = Shared
```

Permissions:

```text
Database permissions:
  Describe

Table permissions:
  Describe
  Select
```

Run the team2 reader query again.

Expected result:

```text
SUCCEEDED
```

This proves the LF-TBAC path:

```text
reader has LF permission for Classification=Shared
team2 database/table has Classification=Shared
Athena query succeeds
```

## Phase 6: Prove Tag Attachment Drives Access

Keep the LF-Tag permission grant in place:

```text
reader can access resources where Classification = Shared
```

Remove the tag from the team2 database:

```text
Database: lakehouse_lf_tbac_team2_sandbox
Remove:   Classification = Shared
```

The table should lose the inherited tag too.

Run the team2 reader query again.

Expected result:

```text
FAILED
Insufficient Lake Formation permission(s): Required Describe on lakehouse_lf_tbac_team2_sandbox
```

Why:

```text
permission rule still exists
but no resource matches Classification=Shared
```

Add `Classification = Shared` back to the team2 database.

Confirm the table inherits it again.

Run the team2 reader query again.

Expected result:

```text
SUCCEEDED
```

This proves:

```text
LF-Tag permission alone does nothing.
Resource tag alone does nothing.

Both must exist:
  principal has permission for the tag expression
  resource has a matching tag
```

## Phase 7: Move Future Defaults To Lake Formation Mode

Add the Lake Formation data lake settings resource in Terraform:

```hcl
resource "aws_lakeformation_data_lake_settings" "this" {
  admins = [var.your_iam_principal_arn]
}
```

Do not add empty `create_database_default_permissions` or
`create_table_default_permissions` blocks.

The goal is:

```text
future databases and tables should not automatically receive IAMAllowedPrincipals
```

Important distinction:

```text
aws_lakeformation_data_lake_settings:
  controls default permissions for future Data Catalog resources

existing IAMAllowedPrincipals rows:
  must be cleaned up separately from existing databases and tables
```

After applying the setting, the Lake Formation console should show:

```text
Use only IAM access control for new databases: unchecked
Use only IAM access control for new tables in new databases: unchecked
```

This does not remove old `IAMAllowedPrincipals` grants from resources that
already exist.

## Phase 8: Final Proof After Cleaning Up Existing Defaults

After manually revoking `IAMAllowedPrincipals` from team1 and team2 database
and table resources, only the default database should still show
`IAMAllowedPrincipals`.

Expected remaining compatibility row:

```text
Principal: IAMAllowedPrincipals
Resource:  Database default
Permission: All
```

The reader role should still query team2:

```bash
aws athena start-query-execution \
  --region eu-west-2 \
  --work-group sandbox-lakehouse-lf-tbac-team2-workgroup \
  --query-execution-context Database=lakehouse_lf_tbac_team2_sandbox \
  --query-string "SELECT * FROM customers;"
```

Expected result:

```text
SUCCEEDED
```

Why:

```text
reader has LF-Tag policy for Classification = Shared
team2 database has Classification = Shared
team2 customers table inherits the tag
```

The reader role should fail against team1:

```bash
aws athena start-query-execution \
  --region eu-west-2 \
  --work-group sandbox-lakehouse-lf-tbac-team1-workgroup \
  --query-execution-context Database=lakehouse_lf_tbac_team1_sandbox \
  --query-string "SELECT * FROM customers;"
```

Expected result:

```text
FAILED
Insufficient Lake Formation permission(s): Required Describe on lakehouse_lf_tbac_team1_sandbox
```

Why:

```text
team1 no longer has IAMAllowedPrincipals
team1 does not have Classification = Shared
reader has no direct Lake Formation grant for team1
```

## Lake Formation Data Location Role And DATA_LOCATION_ACCESS

Lake Formation has two separate concepts around an S3 data location:

```text
1. Registered-location IAM role
2. DATA_LOCATION_ACCESS permission
```

They are related, but they are not the same permission.

### Registered-location IAM Role

When an S3 path is registered in Lake Formation, Lake Formation needs an IAM
role that can physically access that S3 path.

Example registered path:

```text
s3://sandbox-lakehouse-lf-tbac-team2-temp/iceberg/
```

Example role:

```text
lakehouse-lf-tbac-data-location-role
```

This role is the delegated S3/KMS access role for governed data locations.

It needs IAM permissions such as:

```text
s3:ListBucket
s3:GetObject
s3:PutObject
s3:DeleteObject
kms:Decrypt
kms:GenerateDataKey
```

on the registered S3 location and the KMS key used by that data.

This answers:

```text
Can Lake Formation physically access this S3 path?
```

This role is not a human admin role. It is not the role used by analysts or
readers. It is the backing role Lake Formation uses for governed S3 access.

### DATA_LOCATION_ACCESS

`DATA_LOCATION_ACCESS` is a Lake Formation permission granted to a principal
such as an Iceberg creator role.

Example principal:

```text
lakehouse-lf-tbac-iceberg-creator
```

It answers:

```text
Is this principal allowed to create catalog resources that point to this
registered S3 location?
```

For example, to create an Iceberg table under:

```text
s3://sandbox-lakehouse-lf-tbac-team2-temp/iceberg/customers_iceberg/
```

the creator role needs Lake Formation permissions like:

```text
CREATE_TABLE on the database
DATA_LOCATION_ACCESS on the registered S3 location
```

and IAM permissions for the service APIs it calls, such as Glue and Athena.

### The Difference

The registered-location IAM role gives Lake Formation the backing S3/KMS
capability.

The `DATA_LOCATION_ACCESS` grant gives a creator principal permission to use
that governed location when creating tables.

```text
Registered-location IAM role:
  granted IAM S3/KMS permissions
  used by Lake Formation

DATA_LOCATION_ACCESS:
  granted as a Lake Formation permission
  assigned to the creator/user role
```

If the data location role has S3 access but the creator lacks
`DATA_LOCATION_ACCESS`:

```text
Lake Formation can access the path
but the creator is not allowed to create a table there
```

If the creator has `DATA_LOCATION_ACCESS` but the data location role lacks
S3/KMS access:

```text
the creator is allowed by Lake Formation
but Lake Formation cannot physically use the path
```

Both sides are needed for governed table creation.

### Reader And Writer Roles

For registered Lake Formation table data, data reader roles usually do not need
direct S3 object permissions on the governed source data path.

They still need IAM permissions to call AWS services:

```text
athena:StartQueryExecution
athena:GetQueryExecution
athena:GetQueryResults
glue:GetDatabase
glue:GetTable
lakeformation:GetDataAccess
```

They also need Lake Formation data permissions:

```text
DESCRIBE on database
DESCRIBE on table
SELECT on table
```

They still need access to the Athena query result location, because query
results are separate from the governed source table data.

The production-style split is:

```text
Lake Formation data location role:
  has S3/KMS access to governed source data

Creator role:
  has CREATE_TABLE and DATA_LOCATION_ACCESS

Reader role:
  has service IAM permissions and LF read permissions
  does not need broad direct S3 access to governed source data
```

## Terraform-Created Iceberg Table

The goal was to avoid Athena DDL for an Iceberg table under a Lake Formation
registered location.

The pattern tested:

```text
Terraform:
  creates Glue Iceberg table metadata

Athena:
  runs DML only, such as INSERT and SELECT
```

This required AWS provider 6.x. Provider 5.x accepted
`open_table_format_input`, but did not support the nested
`iceberg_table_input` block needed for schema and location.

The provider constraint was changed from:

```hcl
version = "~> 5.0"
```

to:

```hcl
version = "~> 6.0"
```

Then the provider lock file was updated with:

```bash
terraform init -upgrade
```

Terraform created the Iceberg table:

```text
Database: iceberg_learning_db
Table:    customers_iceberg_tf
Location: s3://sandbox-lakehouse-lf-tbac-team2-temp/iceberg/customers_iceberg_tf/
Schema:
  customer_id    int
  customer_name  string
  region         string
```

The table was created with:

```hcl
resource "aws_glue_catalog_table" "customers_iceberg_tf" {
  name          = "customers_iceberg_tf"
  database_name = "iceberg_learning_db"

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
      version            = 2

      iceberg_table_input {
        location = "s3://${aws_s3_bucket.team_temp["team2"].bucket}/iceberg/customers_iceberg_tf/"

        schema {
          schema_id = 0
          type      = "struct"

          fields {
            id       = 1
            name     = "customer_id"
            required = false
            type     = "\"int\""
          }

          fields {
            id       = 2
            name     = "customer_name"
            required = false
            type     = "\"string\""
          }

          fields {
            id       = 3
            name     = "region"
            required = false
            type     = "\"string\""
          }
        }
      }
    }
  }
}
```

After `terraform apply`, Glue showed Iceberg parameters:

```text
table_type = iceberg
metadata_location = s3://.../metadata/00000-...metadata.json
iceberg.table.uuid = ...
```

S3 initially contained only the Iceberg metadata file:

```text
metadata/00000-...metadata.json
```

This proved Terraform/Glue created the initial Iceberg metadata without Athena
DDL.

Athena `SELECT` then succeeded and returned zero rows:

```sql
SELECT * FROM iceberg_learning_db.customers_iceberg_tf;
```

Rows were inserted with Athena DML:

```sql
INSERT INTO customers_iceberg_tf
VALUES
  (1, 'Alice', 'London'),
  (2, 'Ben', 'Manchester'),
  (3, 'Carys', 'Cardiff');
```

After the insert, S3 contained:

```text
data/...parquet
metadata/00000-...metadata.json
metadata/00001-...metadata.json
metadata/...-m0.avro
metadata/snap-...avro
```

Meaning:

```text
Terraform created the Iceberg table and initial metadata.
Athena INSERT used Iceberg to write data files and commit a new snapshot.
```

Important lesson:

```text
Normal external table:
  uploading matching files into the S3 location can be enough

Iceberg table:
  uploaded Parquet files alone are not enough
  files must be committed into Iceberg metadata/snapshots
```

## Later Iceberg Learning Track

The next stage is to compare Terraform-created Iceberg tables with job-created
Iceberg tables.

Planned AWS-native track:

```text
Terraform:
  creates IAM roles
  creates Lake Formation grants
  creates Glue job definition

Glue ETL Spark job:
  creates Iceberg table if missing
  writes seed data
  commits Iceberg snapshots
```

External writer research track:

```text
Evaluate Spark, Flink, Trino, PyIceberg, or other Iceberg-aware tools.
```

An external writer does not have to be AWS Glue, but it must be Iceberg-aware.
It needs to:

```text
create valid Iceberg metadata files
create manifest and snapshot files
write data files to S3
update or register the Glue Catalog pointer
work with IAM, KMS, and Lake Formation constraints
```

Plain Parquet upload is not enough for Iceberg.

## Final Mental Model

The full access equation is:

```text
IAM permission
+ Lake Formation permission
+ matching LF-Tag on the resource
= Athena query succeeds
```

If IAM denies first, the error looks like an IAM `AccessDeniedException`.

If IAM allows but Lake Formation denies, Athena may still return a
`QueryExecutionId`, then the query status becomes `FAILED`.

Common Lake Formation failures:

```text
Required Describe on database
Relation contains no accessible columns
```

Meaning:

```text
Required Describe:
  the role cannot see/use the database or table metadata

Relation contains no accessible columns:
  the role can see the table, but has no SELECT permission on columns
```

For existing resources, the migration order is:

```text
1. Give the intended role explicit Lake Formation access.
2. Test that access works.
3. Remove IAMAllowedPrincipals from the old database/table resources.
4. Test again.
```
