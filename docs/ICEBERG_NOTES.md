# Iceberg Notes

These notes capture the Iceberg-specific learning path from this sandbox.

## Current Checkpoint

The sandbox proved this path:

```text
Terraform:
  registers an Iceberg S3 prefix with Lake Formation
  creates a Lake Formation data location role
  creates an Iceberg creator role
  grants CREATE_TABLE and DATA_LOCATION_ACCESS
  creates a Glue Iceberg table with AWS provider 6.x

Athena:
  runs DML only
  inserts rows into the Terraform-created Iceberg table
  queries the table successfully
```

This avoided Athena DDL for the Terraform-created Iceberg table.

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

### Track A: Terraform Table, Athena DML

This is the path already proven.

```text
Terraform:
  creates Glue Iceberg table metadata
  creates initial Iceberg metadata file

Athena:
  inserts rows with DML
  writes Parquet data files
  commits Iceberg snapshots/manifests
```

This path is useful when the platform wants table definitions controlled by
Terraform, while data changes are still handled by a query engine.

Terraform should not be used to insert rows directly. It is possible to abuse
`local-exec` or `terraform_data` to run an Athena `INSERT`, but that mixes
declarative infrastructure with imperative data mutation.

Problems with inserting data from Terraform:

```text
re-runs can duplicate rows
Terraform state does not track inserted table data cleanly
partial failures are awkward
destroy does not naturally remove inserted rows/snapshots
Iceberg snapshots are data state, not infrastructure state
```

Use Athena, Glue Spark, or another Iceberg-aware engine for data writes.

### Track B: AWS Glue ETL Spark Bootstrap

This is the next AWS-native pattern to test.

```text
Terraform:
  creates IAM roles
  creates Lake Formation grants
  registers S3 data location
  creates or references Glue database
  creates Glue job definition

Glue ETL Spark job:
  creates Iceberg table if missing
  writes seed data
  commits Iceberg snapshots
```

In this pattern, table creation and initial data write can both happen inside
the Glue ETL Spark job.

Example job responsibility:

```text
CREATE TABLE IF NOT EXISTS ... USING iceberg
INSERT rows or write a DataFrame
```

The job uses Spark Iceberg integration under the hood:

```text
Glue ETL script
  -> Spark SQL / DataFrame write
  -> Iceberg Spark connector
  -> Apache Iceberg libraries
  -> S3 data files + metadata files
  -> Glue Catalog table metadata
```

This is closer to a production platform pattern because an Iceberg-aware engine
owns the Iceberg metadata and snapshot commits.

The Glue job role would need IAM permissions such as:

```text
Glue catalog APIs
S3 access to job scripts and temporary files
CloudWatch Logs
KMS access
lakeformation:GetDataAccess
```

And Lake Formation permissions such as:

```text
DESCRIBE on database
CREATE_TABLE on database
DATA_LOCATION_ACCESS on registered S3 location
table permissions needed for writes after creation
```

### Track C: External Iceberg Writer Research

External tools are possible, but they must be Iceberg-aware.

Candidates:

```text
Spark outside AWS
Flink
Trino
PyIceberg
EMR Serverless
Databricks
custom app using Iceberg libraries
```

An external writer does not have to be AWS Glue, but it must be Iceberg-aware.
It needs to create the full Iceberg table state:

```text
create valid Iceberg metadata files
create manifest and snapshot files
write data files to S3
update or register the Glue Catalog pointer
work with IAM, KMS, and Lake Formation constraints
```

The required catalog piece is important:

```text
Glue Catalog table must point to the current Iceberg metadata file.
```

An external tool can either:

```text
use Glue Catalog directly as the Iceberg catalog
```

or:

```text
write the metadata files to S3
then register/update Glue Catalog to point at the current metadata file
```

Plain Parquet upload is not enough for Iceberg. Iceberg will ignore data files
that are not committed into its metadata/snapshot chain.

Evaluation questions for external tools:

```text
Can it write Iceberg v2 tables?
Can it use AWS Glue Catalog as the Iceberg catalog?
Can it write to S3 using AWS auth and KMS?
Can it work with Lake Formation governed access?
Does it require direct S3/IAM permissions instead of LF-governed access?
Can it handle retries and concurrent commits safely?
Can it update the Glue Catalog current metadata pointer correctly?
Can it run cleanly in CI/CD or orchestration?
```

Current preference for this sandbox:

```text
1. Use AWS Glue ETL Spark as the AWS-native baseline.
2. Research external Iceberg writers later as a separate architecture track.
```
